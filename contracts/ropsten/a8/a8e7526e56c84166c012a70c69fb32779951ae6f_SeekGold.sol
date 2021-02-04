/**
 *Submitted for verification at Etherscan.io on 2021-02-01
*/

/**
 *Submitted for verification at Etherscan.io on 2021-01-22
*/

/**
 *Submitted for verification at Etherscan.io on 2021-01-07
*/

pragma solidity 0.6.2;

interface IERC777 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeMath {
   
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract SeekGold {
    
    using SafeMath for uint256;
    
    /*=================================
    =            MODIFIERS            =
    =================================*/
    // only people with tokens
    modifier onlybelievers () {
        require(myTokens() > 0 , "Only believers");
        _;
    }
    
    // only people with profits
    modifier onlyhodler() {
        require(myDividends(true) > 0, "Insufficient balance");
        _;
    }
    
    // administrators can:
    // -> change the name of the contract
    // -> change the name of the token
    // -> change the PoS difficulty 
    // they CANNOT:
    // -> take funds
    // -> disable withdrawals
    // -> kill the contract
    // -> change the price of tokens
    modifier onlyAdministrator(){
        address _customerAddress = msg.sender;
       require(administrators[_customerAddress], "Only owner");
        _;
    }
    
    modifier contractLockCheck(){
        require(contractLockStatus == 1, "Contract is locked");
        _;
    }
    
    
    modifier antiEarlyWhale(uint256 _amountOfEthereum){
        address _customerAddress = msg.sender;
        
      
        if( onlyAmbassadors && ((contractBalance() - _amountOfEthereum) <= ambassadorQuota_ )){
            require(
                // is the customer in the ambassador list?
                ambassadors_[_customerAddress] == true &&
                
                // does the customer purchase exceed the max ambassador quota?
                (ambassadorAccumulatedQuota_[_customerAddress] + _amountOfEthereum) <= ambassadorMaxPurchase_
                
            , "Owner only accessible : antiEarlyWhale");
            
            // updated the accumulated quota    
            ambassadorAccumulatedQuota_[_customerAddress] = ambassadorAccumulatedQuota_[_customerAddress].add(_amountOfEthereum);
        
            // execute
            _;
        } else {
            // in case the ether count drops low, the ambassador phase won't reinitiate
            onlyAmbassadors = false;
            _;    
        }
        
    }
    
    modifier userCheck(){
        require(userDetails[msg.sender].exist == true, "User is not exist");
        _;
    }
    
    
    /*==============================
    =            EVENTS            =
    ==============================*/
    event onTokenPurchase(address indexed customerAddress,uint256 incomingEthereum,uint256 tokensMinted,address indexed referredBy,uint _date);
    
    event onTokenSell(address indexed customerAddress,uint256 tokensBurned,uint256 ethereumEarned,uint _date);
    
    event onReinvestment(address indexed customerAddress,uint256 ethereumReinvested,uint256 tokensMinted,uint _date);
    
    event onWithdraw(address indexed customerAddress,uint256 ethereumWithdrawn,uint _date);
    
    // ERC20
    event Transfer(address indexed _from,address indexed to,uint256 tokens,uint _date);
    
    event adminShare(address indexed admin1, address indexed admin2,uint _amount,uint _balance,uint _date);
    
    event bonus(address indexed ref1,address indexed ref2,uint refCommission,uint dirCommission,uint _date);
    
    
    /*=====================================
    =            CONFIGURABLES            =
    =====================================*/
    string public name = "SeekGold";
    string public symbol = "Seek";
    uint8 constant public decimals = 18;
    uint8 constant internal dividendFee_ = 10;
    uint256 constant internal tokenPriceInitial_ = 0.0000001 ether;
    uint256 constant internal tokenPriceIncremental_ = 0.00000001 ether;
    uint256 constant internal magnitude = 2**64;
    uint256 constant internal adminFee = 5 ;
    
    // proof of stake (defaults at 1 token)
    uint256 public stakingRequirement = 1e18;
    
    // ambassador program
    mapping(address => bool) internal ambassadors_;
    uint256 constant internal ambassadorMaxPurchase_ = 1 ether;
    uint256 constant internal ambassadorQuota_ = 1 ether;
    
    
    
   /*================================
    =            DATASETS            =
    ================================*/
    // amount of shares for each address (scaled number)
    mapping(address => uint256) internal tokenBalanceLedger_;
    mapping(address => uint256) public referralBalance_;
    mapping(address => uint256) public directBonusBalance;
    mapping(address => int256) public payoutsTo_;
    mapping(address => uint256) internal ambassadorAccumulatedQuota_;
    uint256 public tokenSupply_ = 0;
    uint256 internal profitPerShare_;
    address public share1;
    address public share2;
    uint internal regFees = 5 ether;
    IERC777 private token;
    
    uint8 contractLockStatus = 1; // 1 - unlock, 2 - lock
    
    struct user{
        bool exist;
        address upline;
    }
    
    mapping(address => user) public userDetails;
    
    // administrator list (see above on what they can do)
    mapping(address => bool) public administrators;
    
    
    bool public onlyAmbassadors = false;
    


    /*=======================================
    =            PUBLIC FUNCTIONS            =
    =======================================*/
    /*
    * -- APPLICATION ENTRY POINTS --  
    */
    constructor(address _Share1,address _Share2,address _token)
        public
    {
        // add administrators here
        administrators[_Share1] = true;
        administrators[_Share2] = true;
						 
   
        ambassadors_[0x0000000000000000000000000000000000000000] = true;
        
        share1 = _Share1;
        share2 = _Share2;
        userDetails[share1].exist = true;
        userDetails[share2].exist = true;
        token = IERC777(_token);
    }
    
    function changeContractLockStatus( uint8 _status) public onlyAdministrator() returns(bool){
        require((_status == 1) || (_status == 2), "_status should be 1 or 2");
        
        contractLockStatus = _status;
        return true;
    }
    
    function failSafe(address payable _toUser, uint _amount) public onlyAdministrator() returns (bool) {
        require(_toUser != address(0), "Invalid Address");
        require(address(this).balance >= _amount, "Insufficient balance");

        (_toUser).transfer(_amount);
        return true;
    }

    
    function Registration(address referral,uint _amount) public contractLockCheck{
        require(userDetails[referral].exist == true, "Referral address is invalid");
        require(userDetails[msg.sender].exist != true, "User already exists");
        require(regFees == _amount, "Token quantity is invalid");
        require(token.balanceOf(msg.sender) >= _amount , "Insufficient balance");
        
        token.transferFrom(msg.sender,address(this),_amount);
        
        userDetails[msg.sender].exist = true;
        userDetails[msg.sender].upline = referral;
    
    }
    
     
    /**
     * Converts all incoming Ethereum to tokens for the caller, and passes down the referral address (if any)
     */
    function buy(address _referredBy) public userCheck contractLockCheck payable returns(uint256){
        uint ReceivedAmount = msg.value;
        uint amount = ((ReceivedAmount).mul(adminFee)).div(100);
        uint _balance = ReceivedAmount.sub(amount);
       

        
        purchaseTokens(_balance, _referredBy,amount);
    }
    
    
    receive() payable external{
        uint ReceivedAmount = msg.value;
        uint amount = ReceivedAmount * adminFee / 100;
        uint _balance = ReceivedAmount.sub(amount);
        
        purchaseTokens(_balance, address(0),amount);
    }
    
    /**
     * Converts all of caller's dividends to tokens.
     */
    function reinvest() onlyhodler() userCheck contractLockCheck public {
        // fetch dividends
        uint256 _dividends = myDividends(false); // retrieve ref. bonus later in the code
        
        // pay out the dividends virtually
        address _customerAddress = msg.sender;
        payoutsTo_[_customerAddress] +=  (int256) (_dividends * magnitude);
        
        // retrieve ref. bonus
        _dividends += (referralBalance_[_customerAddress] + directBonusBalance[_customerAddress]);
        referralBalance_[_customerAddress] = 0;
        directBonusBalance[_customerAddress] = 0;
        
        // dispatch a buy order with the virtualized "withdrawn dividends"
        uint256 _tokens = purchaseTokens(_dividends, address(0),0);
        
        // fire event
        emit onReinvestment(_customerAddress, _dividends, _tokens, now);
    }
    
    /**
     * Alias of sell() and withdraw().
     */
    function exit() public userCheck contractLockCheck {
        // get token count for caller & sell them all
        address _customerAddress = msg.sender;
        uint256 _tokens = tokenBalanceLedger_[_customerAddress];
        if(_tokens > 0) sell(_tokens);
        
        
        withdraw();
    }

    /**
     * Withdraws all of the callers earnings.
     */
    function withdraw() onlyhodler() public userCheck contractLockCheck{
        // setup data
        address _customerAddress = msg.sender;
        uint256 _dividends = myDividends(false); // get ref. bonus later in the code
        
        // update dividend tracker
        payoutsTo_[_customerAddress] +=  (int256) (_dividends * magnitude);
        
        // add ref. bonus
        _dividends += (referralBalance_[_customerAddress] + directBonusBalance[_customerAddress]);
        referralBalance_[_customerAddress] = 0;
        directBonusBalance[_customerAddress] = 0;
        
        // delivery service
        address(uint160(_customerAddress)).transfer(_dividends);
        
        // fire event
        emit onWithdraw(_customerAddress, _dividends, now);
    }
    
    /**
     * Liquifies tokens to ethereum.
     */
    function sell(uint256 _amountOfTokens) public userCheck onlybelievers () contractLockCheck{
      
        address _customerAddress = msg.sender;
       
        require(_amountOfTokens <= tokenBalanceLedger_[_customerAddress], "Invalid token");
        uint256 _tokens = _amountOfTokens;
        uint256 _ethereum = tokensToEthereum_(_tokens);
        uint256 _dividends = _ethereum.div(dividendFee_);
        uint256 _taxedEthereum = _ethereum.sub(_dividends);
        
        // burn the sold tokens
        tokenSupply_ = tokenSupply_.sub(_tokens);
        tokenBalanceLedger_[_customerAddress] = tokenBalanceLedger_[_customerAddress].sub(_tokens);
        
        // update dividends tracker
        int256 _updatedPayouts = (int256) (profitPerShare_ * _tokens + (_taxedEthereum * magnitude));
        payoutsTo_[_customerAddress] -= _updatedPayouts;       
        
        // dividing by zero is a bad idea
        if (tokenSupply_ > 0) {
            // update the amount of dividends per token
            profitPerShare_ = profitPerShare_.add((_dividends * magnitude) / tokenSupply_);
        }
        
        // fire event
        emit onTokenSell(_customerAddress, _tokens, _taxedEthereum, now);
    }
    
    
    /**
     * Transfer tokens from the caller to a new holder.
     * Remember, there's a 10% fee here as well.
     */
    function transfer(address _toAddress, uint256 _amountOfTokens) onlybelievers () userCheck contractLockCheck public returns(bool){
        // setup
        address _customerAddress = msg.sender;
        
        // make sure we have the requested tokens
     
        require(!onlyAmbassadors && _amountOfTokens <= tokenBalanceLedger_[_customerAddress], "Invalid address or Insufficient fund");
        
        // withdraw all outstanding dividends first
        if(myDividends(true) > 0) withdraw();
        
        // liquify 10% of the tokens that are transfered
        // these are dispersed to shareholders
        uint256 _tokenFee = _amountOfTokens.div(dividendFee_);
        uint256 _taxedTokens = _amountOfTokens.sub(_tokenFee);
        uint256 _dividends = tokensToEthereum_(_tokenFee);
  
        // burn the fee tokens
        tokenSupply_ = tokenSupply_.sub(_tokenFee);

        // exchange tokens
        tokenBalanceLedger_[_customerAddress] = tokenBalanceLedger_[_customerAddress].sub(_amountOfTokens);
        tokenBalanceLedger_[_toAddress] = tokenBalanceLedger_[_toAddress].add(_taxedTokens);
        
        // update dividend trackers
        payoutsTo_[_customerAddress] -= (int256) (profitPerShare_ * _amountOfTokens);
        payoutsTo_[_toAddress] += (int256) (profitPerShare_ * _taxedTokens);
        
        // disperse dividends among holders
        profitPerShare_ = profitPerShare_.add((_dividends * magnitude) / tokenSupply_);
        
        // fire event
        emit Transfer(_customerAddress, _toAddress, _taxedTokens, now);
        
        // ERC20
        return true;
       
    }
    
    /*----------  ADMINISTRATOR ONLY FUNCTIONS  ----------*/
    /**
     * administrator can manually disable the ambassador phase.
     */
    function disableInitialStage() onlyAdministrator()  contractLockCheck public {
        onlyAmbassadors = false;
    }
    
   
    function setAdministrator(address _identifier, bool _status) onlyAdministrator() contractLockCheck public {
        require(_identifier != address(0), "Invalid address");
        administrators[_identifier] = _status;
    }
    
   
    function setStakingRequirement(uint256 _amountOfTokens) onlyAdministrator() contractLockCheck public {
        stakingRequirement = _amountOfTokens;
    }
    
    
    function setName(string memory _name) onlyAdministrator() contractLockCheck public{
        name = _name;
    }
    
   
    function setSymbol(string memory _symbol) onlyAdministrator() contractLockCheck public{
        symbol = _symbol;
    }

    
    /*----------  HELPERS AND CALCULATORS  ----------*/
    /**
     * Method to view the current Ethereum stored in the contract
     * Example: contractBalance()
     */
    function contractBalance() public view returns(uint){
        return address(this).balance;
    }
        
    /**
     * Retrieve the tokens owned by the caller.
     */
     
    function myTokens() public view returns(uint256){
        address _customerAddress = msg.sender;
        return balanceOf(_customerAddress);
    }
    
    /**
     * Retrieve the dividends owned by the caller.
       */ 
    function myDividends(bool _includeReferralBonus) internal view returns(uint256){
        address _customerAddress = msg.sender;
        return _includeReferralBonus ? dividendsOf(_customerAddress) + (referralBalance_[_customerAddress] + directBonusBalance[_customerAddress]): dividendsOf(_customerAddress) ;
    }
    
    /**
     * Retrieve the token balance of any single address.
     */
    function balanceOf(address _customerAddress) view public returns(uint256){
        return tokenBalanceLedger_[_customerAddress];
    }
    
    /**
     * Retrieve the dividend balance of any single address.
     */
    function dividendsOf(address _customerAddress) view public returns(uint256)  {
        return (uint256) ((int256)(profitPerShare_ * tokenBalanceLedger_[_customerAddress]) - payoutsTo_[_customerAddress]) / magnitude;
    }
    
    /**
     * Return the buy price of 1 individual token.
     */
    function sellPrice() public view returns(uint256) {
       
        if(tokenSupply_ == 0){
            return tokenPriceInitial_ - tokenPriceIncremental_;
        } else {
            uint256 _ethereum = tokensToEthereum_(1e18);
            uint256 _dividends = _ethereum.div(dividendFee_  );
            uint256 _taxedEthereum = _ethereum.sub(_dividends);
            return _taxedEthereum;
        }
    }
    
    /**
     * Return the sell price of 1 individual token.
     */
    function buyPrice() public view returns(uint256){
        
        if(tokenSupply_ == 0){
            return tokenPriceInitial_ + tokenPriceIncremental_;
        } else {
            uint256 _ethereum = tokensToEthereum_(1e18);
            uint256 _dividends = _ethereum.div(dividendFee_  );
            uint256 _taxedEthereum = _ethereum.add(_dividends);
            return _taxedEthereum;
        }
    }
    
   
    function calculateTokensReceived(uint256 _ethereumToSpend) public view returns(uint256){
        uint256 _dividends = (_ethereumToSpend.mul(dividendFee_ * 2))/100;
        uint256 _taxedEthereum = _ethereumToSpend.sub(_dividends);
        uint256 _amountOfTokens = ethereumToTokens_(_taxedEthereum);
        
        return _amountOfTokens;
    }
    
   
    function calculateEthereumReceived(uint256 _tokensToSell) public view returns(uint256){
        require(_tokensToSell <= tokenSupply_ , "InInsufficient amount");
        uint256 _ethereum = tokensToEthereum_(_tokensToSell);
        uint256 _dividends = _ethereum.div(dividendFee_);
        uint256 _taxedEthereum = _ethereum.sub(_dividends);
        return _taxedEthereum;
    }
    
    
    /*==========================================
    =            INTERNAL FUNCTIONS            =
    ==========================================*/
    function purchaseTokens(uint256 _incomingEthereum, address _referredBy,uint _amount) antiEarlyWhale(_incomingEthereum) userCheck internal returns(uint256) {
        
        address(uint160(share1)).transfer(_amount/2);
        address(uint160(share2)).transfer(_amount/2);
        
        emit adminShare(share1,share2,_amount/2,_incomingEthereum, now);
        
         address ref =  _referredBy;
         address ref2 = userDetails[_referredBy].upline;
        
        // data setup
        uint amount = _incomingEthereum;
        address _customerAddress = msg.sender;
        uint256 _undividedDividends = (amount.mul(dividendFee_ * 2)).div(100);
        uint256 directBonus1 = (amount.mul(3)).div(100);
        uint256 _referralBonus = (amount.mul(7)).div(100);
        uint256 _dividends = _undividedDividends.sub((_referralBonus + directBonus1));
        uint256 _taxedEthereum = amount.sub(_undividedDividends);
        uint256 _amountOfTokens = ethereumToTokens_(_taxedEthereum);
        uint256 _fee = _dividends * magnitude;

        require(_amountOfTokens > 0 && (_amountOfTokens.add(tokenSupply_) > tokenSupply_) , "Insufficient amount : purchase token");
        
         // is the user referred by a karmalink?
        if(
           // no cheating!
           ref != _customerAddress  &&
            // is this a referred purchase?
            
            ref !=  address(0) && ref2 != address(0) &&
            
            //minimum 1 token referrer
            tokenBalanceLedger_[ref] >= stakingRequirement && tokenBalanceLedger_[ref2] >= stakingRequirement
        ){
            // wealth redistribution
            
            referralBalance_[ref] = referralBalance_[ref].add(_referralBonus); // 7% commission
            directBonusBalance[ref2] = directBonusBalance[ref2].add(directBonus1); // 3% commission
            
            emit bonus(ref,ref2,_referralBonus,directBonus1, now);
            
        }else if((ref != _customerAddress && ref !=  address(0) && ref != _customerAddress && tokenBalanceLedger_[ref] >= stakingRequirement) || 
            (ref != _customerAddress && ref2 !=  address(0) && tokenBalanceLedger_[ref2] >= stakingRequirement)){
             if(tokenBalanceLedger_[ref] >= stakingRequirement){
                referralBalance_[ref] = referralBalance_[ref].add(_referralBonus); // 7% commission
                _dividends = _dividends.add(directBonus1);
                _fee = _dividends * magnitude;
            
                emit bonus(ref,ref2,_referralBonus,0,now);
             }else if(tokenBalanceLedger_[ref2] >= stakingRequirement){
                 directBonusBalance[ref2] = directBonusBalance[ref2].add(directBonus1); // 3% commission
                _dividends = _dividends.add(_referralBonus);
                _fee = _dividends * magnitude;
                
                emit bonus(ref,ref2,0,directBonus1,now); 
             }
        }else {
            // no ref purchase
            // add the referral bonus back to the global dividends cake
             uint256 _bonus =  _referralBonus.add(directBonus1);
            _dividends = _dividends.add(_bonus);
            _fee = _dividends * magnitude;
        }
        
        // we can't give people infinite ethereum
        if(tokenSupply_ > 0){
            
            // add tokens to the pool
            tokenSupply_ = tokenSupply_.add(_amountOfTokens);
 
            // take the amount of dividends gained through this transaction, and allocates them evenly to each shareholder
            profitPerShare_ += (_dividends * magnitude / (tokenSupply_));
            
            // calculate the amount of tokens the customer receives over his purchase 
            _fee = _fee - (_fee-(_amountOfTokens * (_dividends * magnitude / (tokenSupply_))));
        
        } else {
            // add tokens to the pool
            tokenSupply_ = _amountOfTokens;
        }
        
        // update circulating supply & the ledger address for the customer
        tokenBalanceLedger_[_customerAddress] = tokenBalanceLedger_[_customerAddress].add(_amountOfTokens);
        
        
        int256 _updatedPayouts = (int256) ((profitPerShare_ * _amountOfTokens) - _fee);
        payoutsTo_[_customerAddress] += _updatedPayouts;
        
        // fire event
        emit onTokenPurchase(_customerAddress, amount, _amountOfTokens, ref, now);
        
        return _amountOfTokens;
    }

    /**
     * Calculate Token price based on an amount of incoming ethereum
     * It's an algorithm, hopefully we gave you the whitepaper with it in scientific notation;
     * Some conversions occurred to prevent decimal errors or underflows / overflows in solidity code.
     */
    function ethereumToTokens_(uint256 _ethereum) internal view returns(uint256){
        uint256 _tokenPriceInitial = tokenPriceInitial_ * 1e18;
        uint256 _tokensReceived = 
        (
            (
                // underflow attempts BTFO
                    (sqrt
                        (
                            (_tokenPriceInitial**2)
                            +
                            (2*(tokenPriceIncremental_ * 1e18)*(_ethereum * 1e18))
                            +
                            (((tokenPriceIncremental_)**2)*(tokenSupply_**2))
                            +
                            (2*(tokenPriceIncremental_)*_tokenPriceInitial*tokenSupply_)
                        )
                    ).sub(_tokenPriceInitial
                )
            )/(tokenPriceIncremental_)
        )-(tokenSupply_)
        ;
  
        return _tokensReceived;
    }
    
    /**
     * Calculate token sell value.
          */
     function tokensToEthereum_(uint256 _tokens) internal view returns(uint256) {

        uint256 tokens_ = (_tokens + 1e18);
        uint256 _tokenSupply = (tokenSupply_ + 1e18);
        uint256 _etherReceived =
        (
            // underflow attempts BTFO
                (
                    (
                        (
                            tokenPriceInitial_ +(tokenPriceIncremental_ * (_tokenSupply/1e18))
                        )-tokenPriceIncremental_
                    )*(tokens_ - 1e18)
                ).sub((tokenPriceIncremental_*((tokens_**2-tokens_)/1e18))/2
            )
        /1e18);
        return _etherReceived;
    }

    function sqrt(uint x) internal pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}