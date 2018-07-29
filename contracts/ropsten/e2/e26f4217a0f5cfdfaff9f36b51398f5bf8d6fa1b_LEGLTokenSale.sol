pragma solidity ^0.4.19;

contract LEGLToken {
    string  public name = &quot;AltCourt Gold Token&quot;;
    string  public symbol = &quot;LEGL&quot;;
    string  public standard = &quot;LEGL Token v1.0&quot;;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 _value
    );

    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );

    event Burn(address indexed from, uint256 value);

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

//function LEGLToken (uint256 _initialSupply) public {
    function LEGLToken () public {
    
        uint256 _initialSupply = 1000000000;
        
        //totalSupply = _initialSupply;
        totalSupply = _initialSupply * 10 ** uint256(decimals); 
        balanceOf[msg.sender] = totalSupply;
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value);

        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;

        Transfer(msg.sender, _to, _value);

        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;

        Approval(msg.sender, _spender, _value);

        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_value <= balanceOf[_from]);
        require(_value <= allowance[_from][msg.sender]);

        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;

        allowance[_from][msg.sender] -= _value;

        Transfer(_from, _to, _value);

        return true;
    }

    function burn(uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value);
        balanceOf[msg.sender] -= _value;
        totalSupply -= _value;
        Burn(msg.sender, _value);
        return true;
    }

    function burnFrom(address _from, uint256 _value) public returns (bool success) {
        require(balanceOf[_from] >= _value);
        require(_value <= allowance[_from][msg.sender]);
        balanceOf[_from] -= _value;
        allowance[_from][msg.sender] -= _value;
        totalSupply -= _value;
        Burn(_from, _value);
        return true;
    }
}


//Token Generation Event

//pragma solidity ^0.4.19;

//import &quot;./LEGLToken.sol&quot;;

contract LEGLTokenSale {
    address admin;
    LEGLToken public tokenContract;
    uint256 public tokenPrice;
    uint256 public tokensSold;

    event Sell(address _buyer, uint256 _amount);
//function LEGLTokenSale(LEGLToken _tokenContract, uint256 _tokenPrice) public {
    function LEGLTokenSale(LEGLToken _tokenContract) public {
    
        uint256 _tokenPrice = 100000000000;
        admin = msg.sender;
        tokenContract = _tokenContract;
        tokenPrice = _tokenPrice;//1000000000000000;
    }

    function multiply(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    function divide(uint x, uint y) internal pure returns (uint256) {
        uint256 c = x / y;
        return c;
    }

    //function buyTokens(uint256 _numberOfTokens) public payable {
    function buyTokens() public payable {
        uint256 _numberOfTokens;

        _numberOfTokens = divide(msg.value , tokenPrice);
        //require(msg.value == multiply(_numberOfTokens, tokenPrice));
        require(tokenContract.balanceOf(this) >= _numberOfTokens);
        require(tokenContract.transfer(msg.sender, _numberOfTokens));



        tokensSold += _numberOfTokens;
         
          
        Sell(msg.sender, _numberOfTokens);
    }

    // Handle Ethereum sent directly to the sale contract
    function()
        payable
        public
    {
        uint256 _numberOfTokens;

        _numberOfTokens = divide(msg.value , tokenPrice);
        //require(msg.value == multiply(_numberOfTokens, tokenPrice));
        require(tokenContract.balanceOf(this) >= _numberOfTokens);
        require(tokenContract.transfer(msg.sender, _numberOfTokens));



        tokensSold += _numberOfTokens;
         
          
        Sell(msg.sender, _numberOfTokens);
    }


    function setPrice(uint256 _tokenPrice) public {
        require(msg.sender == admin);

        tokenPrice = _tokenPrice;
         
    }

    function endSale() public {
        require(msg.sender == admin);
        require(tokenContract.transfer(admin, tokenContract.balanceOf(this)));

        admin.transfer(address(this).balance);
    }

    function withdraw() public {
        require(msg.sender == admin);
        //require(tokenContract.transfer(admin, tokenContract.balanceOf(this)));

        admin.transfer(address(this).balance);
    }

    function withdrawPartial(uint256 _withdrawAmount) public {
        require(msg.sender == admin);
        require(address(this).balance >= _withdrawAmount);
        //require(tokenContract.transfer(admin, tokenContract.balanceOf(this)));

        admin.transfer(_withdrawAmount);
    }
}