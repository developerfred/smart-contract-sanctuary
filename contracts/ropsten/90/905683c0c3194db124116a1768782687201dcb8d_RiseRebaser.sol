// SPDX-License-Identifier: MIT



pragma solidity 0.6.6;

import "./RiseSafeMath.sol";
        
interface UniswapPairContract {
  
  function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
  }
        

interface RiseTokenInterface {
   
    //Public functions
    function maxScalingFactor() external view returns (uint256);
    function RiseScalingFactor() external view returns (uint256);
    //rebase permissioned
    function rebase(uint256 epoch, uint256 indexDelta, bool positive) external returns (uint256);
}

contract RiseRebaser {

    using RiseSafeMath for uint256;

    modifier onlyGov() {
        require(msg.sender == gov);
        _;
    }

 
    /// @notice an event emitted when deviationThreshold is changed
    event NewDeviationThreshold(uint256 oldDeviationThreshold, uint256 newDeviationThreshold);

    /// @notice Governance address
    address public gov;

  
    /// @notice Spreads out getting to the target price
    uint256 public rebaseLag;

    /// @notice Peg target
    uint256 public targetRate;
    
    // If the current exchange rate is within this fractional distance from the target, no supply
    // update is performed. Fixed point number--same format as the rate.
    // (ie) abs(rate - targetRate) / targetRate < deviationThreshold, then no supply change.
    uint256 public deviationThreshold;

    /// @notice More than this much time must pass between rebase operations.
    uint256 public minRebaseTimeIntervalSec;

    /// @notice Block timestamp of last rebase operation
    uint256 public lastRebaseTimestampSec;

    /// @notice The rebase window begins this many seconds into the minRebaseTimeInterval period.
    // For example if minRebaseTimeInterval is 24hrs, it represents the time of day in seconds.
    uint256 public rebaseWindowOffsetSec;

    /// @notice The length of the time window where a rebase operation is allowed to execute, in seconds.
    uint256 public rebaseWindowLengthSec;

    /// @notice The number of rebase cycles since inception
    uint256 public epoch;

    /// @notice delays rebasing activation to facilitate liquidity
    uint256 public constant rebaseDelay = 0;

    address public RiseAddress;
   
    address public uniswap_Rise_eth_pair;
    
    mapping(address => bool) public whitelistFrom;
    
   

    constructor(
        address RiseAddress_,
        address RiseETHPair_
    )
        public
    {
          minRebaseTimeIntervalSec = 23 hours;
          rebaseWindowOffsetSec = 0; // 00:00 UTC rebases
       
          // Default target rate of 0.01 ETH
          targetRate = 10**8;

          // Default lag of 5
          rebaseLag = 5;

          // 5%
          deviationThreshold = 5 * 10**7;

          // 24 hours
          rebaseWindowLengthSec = 24 hours;
          
          uniswap_Rise_eth_pair = RiseETHPair_;
          RiseAddress = RiseAddress_;

          gov = msg.sender;
    }

  
  
  
    
     function setWhitelistedFrom(address _addr, bool _whitelisted) external onlyGov {
        whitelistFrom[_addr] = _whitelisted;
    }
    
    
     function _isWhitelisted(address _from) internal view returns (bool) {
        return whitelistFrom[_from];
    }
    
    /**
     * @notice Initiates a new rebase operation, provided the minimum time period has elapsed.
     *
     * @dev The supply adjustment equals (_totalSupply * DeviationFromTargetRate) / rebaseLag
     *      Where DeviationFromTargetRate is (MarketOracleRate - targetRate) / targetRate
     *      and targetRate is 1e18
     */
    function rebase()
        public
    {
        // EOA only
        require(msg.sender == tx.origin);
        require(_isWhitelisted(msg.sender));
        // ensure rebasing at correct time
        _inRebaseWindow();
        

        require(lastRebaseTimestampSec.add(minRebaseTimeIntervalSec) < now);

        // Snap the rebase time to the start of this window.
        lastRebaseTimestampSec = now;

        epoch = epoch.add(1);

        // get price from uniswap v2;
        uint256 exchangeRate = getPrice();

        // calculates % change to supply
        (uint256 offPegPerc, bool positive) = computeOffPegPerc(exchangeRate);

        uint256 indexDelta = offPegPerc;

        // Apply the Dampening factor.
        indexDelta = indexDelta.div(rebaseLag);

        RiseTokenInterface Rise = RiseTokenInterface(RiseAddress);

        if (positive) {
            require(Rise.RiseScalingFactor().mul(uint256(10**9).add(indexDelta)).div(10**9) < Rise.maxScalingFactor(), "new scaling factor will be too big");
        }
		
        // rebase
        Rise.rebase(epoch, indexDelta, positive);
        assert(Rise.RiseScalingFactor() <= Rise.maxScalingFactor());

  }
  
 
      function getPrice() public view returns (uint256) {
        (uint RiseReserve, uint ethReserve, ) = UniswapPairContract(uniswap_Rise_eth_pair).getReserves();
        uint RisePrice = ethReserve.mul(10**9).div(RiseReserve);
        return RisePrice;
    }

    function setDeviationThreshold(uint256 deviationThreshold_)
        external
        onlyGov
    {
        require(deviationThreshold > 0);
        uint256 oldDeviationThreshold = deviationThreshold;
        deviationThreshold = deviationThreshold_;
        emit NewDeviationThreshold(oldDeviationThreshold, deviationThreshold_);
    }


    /**
     * @notice Sets the rebase lag parameter.
               It is used to dampen the applied supply adjustment by 1 / rebaseLag
               If the rebase lag R, equals 1, the smallest value for R, then the full supply
               correction is applied on each rebase cycle.
               If it is greater than 1, then a correction of 1/R of is applied on each rebase.
     * @param rebaseLag_ The new rebase lag parameter.
     */
     
     
    function setRebaseLag(uint256 rebaseLag_)
        external
        onlyGov
    {
        require(rebaseLag_ > 0);
        rebaseLag = rebaseLag_;
    }
    
    
    
    /**
     * @notice Sets the targetRate parameter.
     * @param targetRate_ The new target rate parameter.
     */
     
     
    function setTargetRate(uint256 targetRate_)
        external
        onlyGov
    {
        require(targetRate_ > 0);
        targetRate = targetRate_;
    }
    
    

    /**
     * @notice Sets the parameters which control the timing and frequency of
     *         rebase operations.
     *         a) the minimum time period that must elapse between rebase cycles.
     *         b) the rebase window offset parameter.
     *         c) the rebase window length parameter.
     * @param minRebaseTimeIntervalSec_ More than this much time must pass between rebase
     *        operations, in seconds.
     * @param rebaseWindowOffsetSec_ The number of seconds from the beginning of
              the rebase interval, where the rebase window begins.
     * @param rebaseWindowLengthSec_ The length of the rebase window in seconds.
     */
    function setRebaseTimingParameters(
        uint256 minRebaseTimeIntervalSec_,
        uint256 rebaseWindowOffsetSec_,
        uint256 rebaseWindowLengthSec_)
        external
        onlyGov
    {
        require(minRebaseTimeIntervalSec_ > 0);
        require(rebaseWindowOffsetSec_ < minRebaseTimeIntervalSec_);

        minRebaseTimeIntervalSec = minRebaseTimeIntervalSec_;
        rebaseWindowOffsetSec = rebaseWindowOffsetSec_;
        rebaseWindowLengthSec = rebaseWindowLengthSec_;
    }

    /**
     * @return If the latest block timestamp is within the rebase time window it, returns true.
     *         Otherwise, returns false.
     */
    function inRebaseWindow() public view returns (bool) {

        // rebasing is delayed until there is a liquid market
        _inRebaseWindow();
        return true;
    }

    function _inRebaseWindow() internal view {
        require(now.mod(minRebaseTimeIntervalSec) >= rebaseWindowOffsetSec, "too early");
        require(now.mod(minRebaseTimeIntervalSec) < (rebaseWindowOffsetSec.add(rebaseWindowLengthSec)), "too late");
    }

    /**
     * @return Computes in % how far off market is from peg
     */
    function computeOffPegPerc(uint256 rate)
        private
        view
        returns (uint256, bool)
    {
        if (withinDeviationThreshold(rate)) {
            return (0, false);
        }

        // indexDelta =  (rate - targetRate) / targetRate
        if (rate > targetRate) {
            return (rate.sub(targetRate).mul(10**9).div(targetRate), true);
        } else {
            return (targetRate.sub(rate).mul(10**9).div(targetRate), false);
        }
    }

    /**
     * @param rate The current exchange rate, an 18 decimal fixed point number.
     * @return If the rate is within the deviation threshold from the target rate, returns true.
     *         Otherwise, returns false.
     */
    function withinDeviationThreshold(uint256 rate)
        private
        view
        returns (bool)
    {
        uint256 absoluteDeviationThreshold = targetRate.mul(deviationThreshold)
            .div(10**9);

        return (rate < targetRate && targetRate.sub(rate) < absoluteDeviationThreshold);
    }
}