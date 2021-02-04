// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IDsecDistribution.sol";

contract DsecDistribution is IDsecDistribution {
    using SafeMath for uint256;

    uint256 public constant DSEC_WITHDRAW_PENALTY_RATE = 20;
    uint256 public constant TOTAL_NUMBER_OF_EPOCHS = 20;

    address public governanceAccount;
    address public poolAccount;

    uint256[TOTAL_NUMBER_OF_EPOCHS] public totalDsec;

    struct GovernanceFormingParams {
        uint256 startTimestamp;
        uint256 epochDuration;
        uint256 intervalBetweenEpochs;
        uint256 endTimestamp;
    }

    GovernanceFormingParams public governanceForming;

    mapping(address => uint256[TOTAL_NUMBER_OF_EPOCHS]) private _dsecs;
    mapping(address => bool[TOTAL_NUMBER_OF_EPOCHS]) private _redeemedDsec;
    bool[TOTAL_NUMBER_OF_EPOCHS] private _redeemedTeamReward;

    event DsecAdd(
        address account,
        uint256 amount,
        uint256 timestamp,
        uint256 epoch,
        uint256 dsec
    );
    event DsecRemove(
        address account,
        uint256 amount,
        uint256 timestamp,
        uint256 epoch,
        uint256 dsec
    );
    event DsecRedeem(
        address account,
        uint256 epoch,
        uint256 distributionAmount,
        uint256 rewardAmount
    );
    event TeamRewardRedeem(address sender, uint256 epoch);

    constructor(
        uint256 epoch0StartTimestamp,
        uint256 epochDuration,
        uint256 intervalBetweenEpochs
    ) {
        governanceAccount = msg.sender;
        poolAccount = msg.sender;
        governanceForming = GovernanceFormingParams({
            startTimestamp: epoch0StartTimestamp,
            epochDuration: epochDuration,
            intervalBetweenEpochs: intervalBetweenEpochs,
            endTimestamp: epoch0StartTimestamp
                .add(TOTAL_NUMBER_OF_EPOCHS.mul(epochDuration))
                .add(TOTAL_NUMBER_OF_EPOCHS.sub(1).mul(intervalBetweenEpochs))
        });
    }

    function setGovernanceAccount(address account) external {
        require(msg.sender == governanceAccount, "must be governance account");
        governanceAccount = account;
    }

    function setPoolAccount(address account) external {
        require(msg.sender == governanceAccount, "must be governance account");
        poolAccount = account;
    }

    function addDsec(address account, uint256 amount) external override {
        require(msg.sender == poolAccount, "must be pool account");
        require(account != address(0), "add to zero address");
        require(amount != 0, "add zero amount");

        (uint256 currentEpoch, uint256 currentDsec) =
            getDsecForTransferNow(amount);
        if (currentEpoch >= TOTAL_NUMBER_OF_EPOCHS) {
            return;
        }

        _dsecs[account][currentEpoch] = _dsecs[account][currentEpoch].add(
            currentDsec
        );
        totalDsec[currentEpoch] = totalDsec[currentEpoch].add(currentDsec);

        uint256 nextEpoch = currentEpoch.add(1);
        if (nextEpoch < TOTAL_NUMBER_OF_EPOCHS) {
            for (uint256 i = nextEpoch; i < TOTAL_NUMBER_OF_EPOCHS; i++) {
                uint256 futureDsec =
                    amount.mul(governanceForming.epochDuration);
                _dsecs[account][i] = _dsecs[account][i].add(futureDsec);
                totalDsec[i] = totalDsec[i].add(futureDsec);
            }
        }

        emit DsecAdd(
            account,
            amount,
            block.timestamp,
            currentEpoch,
            currentDsec
        );
    }

    function removeDsec(address account, uint256 amount) external override {
        require(msg.sender == poolAccount, "must be pool account");
        require(account != address(0), "remove from zero address");
        require(amount != 0, "remove zero amount");

        (uint256 currentEpoch, uint256 currentDsec) =
            getDsecForTransferNow(amount);
        if (currentEpoch >= TOTAL_NUMBER_OF_EPOCHS) {
            return;
        }

        if (_dsecs[account][currentEpoch] == 0) {
            return;
        }

        uint256 dsecRemove =
            currentDsec.mul(DSEC_WITHDRAW_PENALTY_RATE.add(100)).div(100);

        uint256 accountDsecRemove =
            (dsecRemove < _dsecs[account][currentEpoch])
                ? dsecRemove
                : _dsecs[account][currentEpoch];
        _dsecs[account][currentEpoch] = _dsecs[account][currentEpoch].sub(
            accountDsecRemove,
            "insufficient account dsec"
        );
        totalDsec[currentEpoch] = totalDsec[currentEpoch].sub(
            accountDsecRemove,
            "insufficient total dsec"
        );

        uint256 nextEpoch = currentEpoch.add(1);
        if (nextEpoch < TOTAL_NUMBER_OF_EPOCHS) {
            for (uint256 i = nextEpoch; i < TOTAL_NUMBER_OF_EPOCHS; i++) {
                uint256 futureDsecRemove =
                    amount
                        .mul(governanceForming.epochDuration)
                        .mul(DSEC_WITHDRAW_PENALTY_RATE.add(100))
                        .div(100);
                uint256 futureAccountDsecRemove =
                    (futureDsecRemove < _dsecs[account][i])
                        ? futureDsecRemove
                        : _dsecs[account][i];
                _dsecs[account][i] = _dsecs[account][i].sub(
                    futureAccountDsecRemove,
                    "insufficient account future dsec"
                );
                totalDsec[i] = totalDsec[i].sub(
                    futureAccountDsecRemove,
                    "insufficient total future dsec"
                );
            }
        }

        emit DsecRemove(
            account,
            amount,
            block.timestamp,
            currentEpoch,
            accountDsecRemove
        );
    }

    function redeemDsec(
        address account,
        uint256 epoch,
        uint256 distributionAmount
    ) external override returns (uint256) {
        require(msg.sender == poolAccount, "must be pool account");
        require(account != address(0), "redeem for zero address");

        uint256 rewardAmount =
            calculateRewardFor(account, epoch, distributionAmount);
        if (rewardAmount == 0) {
            return 0;
        }

        if (hasRedeemedDsec(account, epoch)) {
            return 0;
        }

        _redeemedDsec[account][epoch] = true;
        emit DsecRedeem(account, epoch, distributionAmount, rewardAmount);
        return rewardAmount;
    }

    function redeemTeamReward(uint256 epoch) external override {
        require(msg.sender == poolAccount, "must be pool account");
        require(epoch < TOTAL_NUMBER_OF_EPOCHS, "governance forming ended");

        uint256 currentEpoch = getCurrentEpoch();
        require(epoch < currentEpoch, "only for completed epochs");

        require(!hasRedeemedTeamReward(epoch), "already redeemed");

        _redeemedTeamReward[epoch] = true;
        emit TeamRewardRedeem(msg.sender, epoch);
    }

    function calculateRewardFor(
        address account,
        uint256 epoch,
        uint256 distributionAmount
    ) public view returns (uint256) {
        require(distributionAmount != 0, "zero distribution amount");

        if (epoch >= TOTAL_NUMBER_OF_EPOCHS) {
            return 0;
        }

        uint256 currentEpoch = getCurrentEpoch();
        if (epoch >= currentEpoch) {
            return 0;
        }

        return getRewardFor(account, epoch, distributionAmount);
    }

    function estimateRewardForCurrentEpoch(
        address account,
        uint256 distributionAmount
    ) public view returns (uint256) {
        require(distributionAmount != 0, "zero distribution amount");

        uint256 currentEpoch = getCurrentEpoch();
        return getRewardFor(account, currentEpoch, distributionAmount);
    }

    function hasRedeemedDsec(address account, uint256 epoch)
        public
        view
        returns (bool)
    {
        require(epoch < TOTAL_NUMBER_OF_EPOCHS, "governance forming ended");

        return _redeemedDsec[account][epoch];
    }

    function hasRedeemedTeamReward(uint256 epoch) public view returns (bool) {
        require(epoch < TOTAL_NUMBER_OF_EPOCHS, "governance forming ended");

        return _redeemedTeamReward[epoch];
    }

    function getCurrentEpoch() public view returns (uint256) {
        return getEpoch(block.timestamp);
    }

    function getCurrentEpochStartTimestamp()
        public
        view
        returns (uint256, uint256)
    {
        return getEpochStartTimestamp(block.timestamp);
    }

    function getCurrentEpochEndTimestamp()
        public
        view
        returns (uint256, uint256)
    {
        return getEpochEndTimestamp(block.timestamp);
    }

    function getEpoch(uint256 timestamp) public view returns (uint256) {
        if (timestamp < governanceForming.startTimestamp) {
            return 0;
        }

        if (timestamp >= governanceForming.endTimestamp) {
            return TOTAL_NUMBER_OF_EPOCHS;
        }

        return
            timestamp
                .sub(governanceForming.startTimestamp, "before epoch 0")
                .add(governanceForming.intervalBetweenEpochs)
                .div(
                governanceForming.epochDuration.add(
                    governanceForming.intervalBetweenEpochs
                )
            );
    }

    function getEpochStartTimestamp(uint256 timestamp)
        public
        view
        returns (uint256, uint256)
    {
        uint256 epoch = getEpoch(timestamp);
        return (epoch, getStartTimestampForEpoch(epoch));
    }

    function getStartTimestampForEpoch(uint256 epoch)
        public
        view
        returns (uint256)
    {
        if (epoch >= TOTAL_NUMBER_OF_EPOCHS) {
            return 0;
        }

        if (epoch == 0) {
            return governanceForming.startTimestamp;
        }

        return
            governanceForming.startTimestamp.add(
                epoch.mul(
                    governanceForming.epochDuration.add(
                        governanceForming.intervalBetweenEpochs
                    )
                )
            );
    }

    function getEpochEndTimestamp(uint256 timestamp)
        public
        view
        returns (uint256, uint256)
    {
        uint256 epoch = getEpoch(timestamp);
        return (epoch, getEndTimestampForEpoch(epoch));
    }

    function getEndTimestampForEpoch(uint256 epoch)
        public
        view
        returns (uint256)
    {
        if (epoch >= TOTAL_NUMBER_OF_EPOCHS) {
            return 0;
        }

        return
            governanceForming
                .startTimestamp
                .add(epoch.add(1).mul(governanceForming.epochDuration))
                .add(epoch.mul(governanceForming.intervalBetweenEpochs));
    }

    function getStartEndTimestampsForEpoch(uint256 epoch)
        public
        view
        returns (uint256, uint256)
    {
        return (
            getStartTimestampForEpoch(epoch),
            getEndTimestampForEpoch(epoch)
        );
    }

    function getSecondsUntilCurrentEpochEnd()
        public
        view
        returns (uint256, uint256)
    {
        return getSecondsUntilEpochEnd(block.timestamp);
    }

    function getSecondsUntilEpochEnd(uint256 timestamp)
        public
        view
        returns (uint256, uint256)
    {
        (uint256 endEpoch, uint256 epochEndTimestamp) =
            getEpochEndTimestamp(timestamp);
        if (timestamp >= epochEndTimestamp) {
            return (endEpoch, 0);
        }

        (uint256 startEpoch, uint256 epochStartTimestamp) =
            getEpochStartTimestamp(timestamp);
        require(epochStartTimestamp > 0, "unexpected 0 epoch start");
        require(endEpoch == startEpoch, "start/end different epochs");

        uint256 startTimestamp =
            (timestamp < epochStartTimestamp) ? epochStartTimestamp : timestamp;
        return (
            endEpoch,
            epochEndTimestamp.sub(startTimestamp, "after end of epoch")
        );
    }

    function getDsecForTransferNow(uint256 amount)
        public
        view
        returns (uint256, uint256)
    {
        (uint256 currentEpoch, uint256 secondsUntilCurrentEpochEnd) =
            getSecondsUntilCurrentEpochEnd();
        return (currentEpoch, amount.mul(secondsUntilCurrentEpochEnd));
    }

    function dsecBalanceFor(address account, uint256 epoch)
        public
        view
        returns (uint256)
    {
        if (epoch >= TOTAL_NUMBER_OF_EPOCHS) {
            return 0;
        }

        uint256 currentEpoch = getCurrentEpoch();
        if (epoch > currentEpoch) {
            return 0;
        }

        return _dsecs[account][epoch];
    }

    function getRewardFor(
        address account,
        uint256 epoch,
        uint256 distributionAmount
    ) internal view returns (uint256) {
        require(distributionAmount != 0, "zero distribution amount");

        if (epoch >= TOTAL_NUMBER_OF_EPOCHS) {
            return 0;
        }

        if (totalDsec[epoch] == 0) {
            return 0;
        }

        if (_dsecs[account][epoch] == 0) {
            return 0;
        }

        uint256 rewardAmount =
            _dsecs[account][epoch].mul(distributionAmount).div(
                totalDsec[epoch]
            );
        return rewardAmount;
    }
}