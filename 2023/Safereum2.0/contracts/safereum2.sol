// ░██████╗░█████╗░███████╗██╗░░░██╗  ██████╗░██╗░░░██╗
// ██╔════╝██╔══██╗██╔════╝██║░░░██║  ██╔══██╗╚██╗░██╔╝
// ╚█████╗░███████║█████╗░░██║░░░██║  ██████╦╝░╚████╔╝░
// ░╚═══██╗██╔══██║██╔══╝░░██║░░░██║  ██╔══██╗░░╚██╔╝░░
// ██████╔╝██║░░██║██║░░░░░╚██████╔╝  ██████╦╝░░░██║░░░
// ╚═════╝░╚═╝░░╚═╝╚═╝░░░░░░╚═════╝░  ╚═════╝░░░░╚═╝░░░

// ░█████╗░░█████╗░██╗███╗░░██╗░██████╗██╗░░░██╗██╗░░░░░████████╗░░░███╗░░██╗███████╗████████╗
// ██╔══██╗██╔══██╗██║████╗░██║██╔════╝██║░░░██║██║░░░░░╚══██╔══╝░░░████╗░██║██╔════╝╚══██╔══╝
// ██║░░╚═╝██║░░██║██║██╔██╗██║╚█████╗░██║░░░██║██║░░░░░░░░██║░░░░░░██╔██╗██║█████╗░░░░░██║░░░
// ██║░░██╗██║░░██║██║██║╚████║░╚═══██╗██║░░░██║██║░░░░░░░░██║░░░░░░██║╚████║██╔══╝░░░░░██║░░░
// ╚█████╔╝╚█████╔╝██║██║░╚███║██████╔╝╚██████╔╝███████╗░░░██║░░░██╗██║░╚███║███████╗░░░██║░░░
// ░╚════╝░░╚════╝░╚═╝╚═╝░░╚══╝╚═════╝░░╚═════╝░╚══════╝░░░╚═╝░░░╚═╝╚═╝░░╚══╝╚══════╝░░░╚═╝░░░

// SAFU By Coinsult

// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
   
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library Address {
    function isContract(address account) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }

    function sendValue(address payable recipient, uint256 amount) internal returns(bool){
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        return success;
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }

    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
    }

    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        return _functionCallWithValue(target, data, value, errorMessage);
    }

    function _functionCallWithValue(address target, bytes memory data, uint256 weiValue, string memory errorMessage) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

contract SAFEREUM2 is Context, IERC20, Ownable {
    using Address for address;
    using Address for address payable;

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) private _isExcludedFromFees;
    mapping (address => bool) private _isExcluded;
    address[] private _excluded;

    string private _name     = "Safereum2.0";
    string private _symbol   = "SAFEREUM2.0";
    uint8  private _decimals = 9;
   
    uint256 private constant MAX = type(uint256).max;
    uint256 private _tTotal = 1e12 * (10 ** _decimals);
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    uint256 private taxFeeonBuy;
    uint256 private taxFeeonSell;

    uint256 private liquidityFeeonBuy;
    uint256 private liquidityFeeonSell;

    uint256 private growthFundFeeonBuy;
    uint256 private growthFundFeeonSell;

    uint256 private _taxFee;
    uint256 private _liquidityFee;
    uint256 private _growthFundFee;

    uint256 public totalBuyFees;
    uint256 public totalSellFees;

    address public growthFundWallet;

    bool public walletToWalletTransferWithoutFee;
    
    address private DEAD = 0x000000000000000000000000000000000000dEaD;

    IUniswapV2Router02 public  uniswapV2Router;
    address public  uniswapV2Pair;

    bool private inSwapAndLiquify;
    bool public swapEnabled;
    bool public tradingEnabled;
    uint256 public swapTokensAtAmount;
    
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event GrowthFundWalletChanged(address growthFundWallet);
    event SwapEnabledUpdated(bool enabled);
    event SwapAndLiquify(uint256 tokensSwapped, uint256 bnbReceived, uint256 tokensIntoLiqudity);
    event SwapAndSendGrowthFund(uint256 tokensSwapped, uint256 bnbSend);
    event SwapTokensAtAmountUpdated(uint256 amount);
    event BuyFeesChanged(uint256 taxFee, uint256 liquidityFee, uint256 growthFundFee);
    event SellFeesChanged(uint256 taxFee, uint256 liquidityFee, uint256 growthFundFee);
    event WalletToWalletTransferWithoutFeeEnabled(bool enabled);
    
    constructor() 
    {        
        address router;
        if (block.chainid == 56) {
            router = 0x10ED43C718714eb63d5aA57B78B54704E256024E; 
        } else if (block.chainid == 97) {
            router =  0xD99D1c33F9fC3444f8101754aBC46c52416550D1; 
        } else if (block.chainid == 1 || block.chainid == 5) {
            router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; 
        } else {
            revert();
        }

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(router);
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;

        _approve(address(this), address(uniswapV2Router), MAX);

        taxFeeonBuy = 2;
        taxFeeonSell = 2;

        liquidityFeeonBuy = 0;
        liquidityFeeonSell = 0;

        growthFundFeeonBuy = 1;
        growthFundFeeonSell = 1;

        totalBuyFees = taxFeeonBuy + liquidityFeeonBuy + growthFundFeeonBuy;
        totalSellFees = taxFeeonSell + liquidityFeeonSell + growthFundFeeonSell;

        growthFundWallet = 0xEbB69Ad6a5de38Ba060DB3672a8F07459d31C412;
        
        swapEnabled = true;
        swapTokensAtAmount = _tTotal / 5000;
    
        walletToWalletTransferWithoutFee = false;
        
        _isExcludedFromFees[owner()] = true;
        _isExcludedFromFees[address(0xdead)] = true;
        _isExcludedFromFees[address(this)] = true;

        _isExcluded[address(this)] = true;
        _isExcluded[address(0x5E5b9bE5fd939c578ABE5800a90C566eeEbA44a5)] = true; //pinklock
        _isExcluded[address(0xdead)] = true;
        _isExcluded[address(uniswapV2Pair)] = true;

        _rOwned[owner()] = _rTotal;
        _tOwned[owner()] = _tTotal;

        emit Transfer(address(0), owner(), _tTotal);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] - subtractedValue);
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalReflectionDistributed() public view returns (uint256) {
        return _tFeeTotal;
    }

    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(!_isExcluded[sender], "Excluded addresses cannot call this function");
        (uint256 rAmount,,,,,,) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _rTotal = _rTotal - rAmount;
        _tFeeTotal = _tFeeTotal + tAmount;
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,,,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount / currentRate;
    }

    function excludeFromReward(address account) public onlyOwner() {
        require(!_isExcluded[account], "Account is already excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner() {
        require(_isExcluded[account], "Account is already included");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    receive() external payable {}

    function claimStuckTokens(address token) external onlyOwner {
        require(token != address(this), "Owner cannot claim native tokens");
        if (token == address(0x0)) {
            payable(msg.sender).sendValue(address(this).balance);
            return;
        }
        IERC20 ERC20token = IERC20(token);
        uint256 balance = ERC20token.balanceOf(address(this));
        ERC20token.transfer(msg.sender, balance);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal - rFee;
        _tFeeTotal = _tFeeTotal + tFee;
    }

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tGrowthFund) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tLiquidity, tGrowthFund, _getRate());
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tLiquidity, tGrowthFund);
    }

    function _getTValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256) {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tLiquidity = calculateLiquidityFee(tAmount);
        uint256 tGrowthFund = calculateGrowthFundFee(tAmount);
        uint256 tTransferAmount = tAmount - tFee - tLiquidity - tGrowthFund;
        return (tTransferAmount, tFee, tLiquidity, tGrowthFund);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tLiquidity, uint256 tGrowthFund, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount * currentRate;
        uint256 rFee = tFee * currentRate;
        uint256 rLiquidity = tLiquidity * currentRate;
        uint256 rGrowthFund = tGrowthFund * currentRate;
        uint256 rTransferAmount = rAmount - rFee - rLiquidity - rGrowthFund;
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;      
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply - _rOwned[_excluded[i]];
            tSupply = tSupply - _tOwned[_excluded[i]];
        }
        if (rSupply < _rTotal / _tTotal) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }
    
    function _takeLiquidity(uint256 tLiquidity) private {
        if (tLiquidity > 0) {
            uint256 currentRate =  _getRate();
            uint256 rLiquidity = tLiquidity * currentRate;
            _rOwned[address(this)] = _rOwned[address(this)] + rLiquidity;
            if(_isExcluded[address(this)])
                _tOwned[address(this)] = _tOwned[address(this)] + tLiquidity;
        }
    }

    function _takeGrowthFund(uint256 tGrowthFund) private {
        if (tGrowthFund > 0) {
            uint256 currentRate =  _getRate();
            uint256 rGrowthFund = tGrowthFund * currentRate;
            _rOwned[address(this)] = _rOwned[address(this)] + rGrowthFund;
            if(_isExcluded[address(this)])
                _tOwned[address(this)] = _tOwned[address(this)] + tGrowthFund;
        }
    }
    
    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount * _taxFee / 100;
    }

    function calculateLiquidityFee(uint256 _amount) private view returns (uint256) {
        return _amount * _liquidityFee / 100;
    }
    
    function calculateGrowthFundFee(uint256 _amount) private view returns (uint256) {
        return _amount * _growthFundFee / 100;
    }
    
    function removeAllFee() private {
        if(_taxFee == 0 && _liquidityFee == 0 && _growthFundFee == 0) return;
        
        _taxFee = 0;
        _growthFundFee = 0;
        _liquidityFee = 0;
    }
    
    function setBuyFee() private{
        if(_taxFee == taxFeeonBuy && _liquidityFee == liquidityFeeonBuy && _growthFundFee == growthFundFeeonBuy) return;

        _taxFee = taxFeeonBuy;
        _growthFundFee = growthFundFeeonBuy;
        _liquidityFee = liquidityFeeonBuy;
    }

    function setSellFee() private{
        if(_taxFee == taxFeeonSell && _liquidityFee == liquidityFeeonSell && _growthFundFee == growthFundFeeonSell) return;

        _taxFee = taxFeeonSell;
        _growthFundFee = growthFundFeeonSell;
        _liquidityFee = liquidityFeeonSell;
    }
    
    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFees[account];
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function enableTrading() external onlyOwner{
        require(tradingEnabled == false, "Trading is already enabled");
        tradingEnabled = true;
    }
    
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        if(!_isExcludedFromFees[from] && !_isExcludedFromFees[to]) {
            require(tradingEnabled, "Trading is not enabled yet");
        }

        uint256 contractTokenBalance = balanceOf(address(this));        
        bool overMinTokenBalance = contractTokenBalance >= swapTokensAtAmount;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            to == uniswapV2Pair &&
            swapEnabled
        ) {
            inSwapAndLiquify = true;
            
            uint256 growthFundShare = growthFundFeeonBuy + growthFundFeeonSell;
            uint256 liquidityShare = liquidityFeeonBuy + liquidityFeeonSell;
            uint256 totalShare = growthFundShare + liquidityShare;
            if(totalShare > 0) {
                if(liquidityShare > 0) {
                    uint256 liquidityTokens = (contractTokenBalance * liquidityShare) / totalShare;
                    swapAndLiquify(liquidityTokens);
                }
                
                if(growthFundShare > 0) {
                    uint256 growthFundTokens = (contractTokenBalance * growthFundShare) / totalShare;
                    swapAndSendGrowthFund(growthFundTokens);
                } 
            }
            inSwapAndLiquify = false;
        }
        
        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from,to,amount);
    }

    function swapAndLiquify(uint256 tokens) private {
        uint256 half = tokens / 2;
        uint256 otherHalf = tokens - half;

        uint256 initialBalance = address(this).balance;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            half,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp);
        
        uint256 newBalance = address(this).balance - initialBalance;

        uniswapV2Router.addLiquidityETH{value: newBalance}(
            address(this),
            otherHalf,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            DEAD,
            block.timestamp
        );

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapAndSendGrowthFund(uint256 tokenAmount) private {
        uint256 initialBalance = address(this).balance;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp);

        uint256 newBalance = address(this).balance - initialBalance;

        payable(growthFundWallet).sendValue(newBalance);

        emit SwapAndSendGrowthFund(tokenAmount, newBalance);
    }

    function setSwapTokensAtAmount(uint256 newAmount) external onlyOwner() {
        require(newAmount > totalSupply() / 1e5, "SwapTokensAtAmount must be greater than 0.001% of total supply");
        swapTokensAtAmount = newAmount;
        emit SwapTokensAtAmountUpdated(newAmount);
    }
    
    function setSwapEnabled(bool _enabled) external onlyOwner {
        swapEnabled = _enabled;
        emit SwapEnabledUpdated(_enabled);
    }

    function _tokenTransfer(address sender, address recipient, uint256 amount) private {
         if (_isExcludedFromFees[sender] || 
            _isExcludedFromFees[recipient] 
            ) {
            removeAllFee();
        }else if(recipient == uniswapV2Pair){
            setSellFee();
        }else if(sender == uniswapV2Pair){
            setBuyFee();
        }else if(walletToWalletTransferWithoutFee){
            removeAllFee();
        }else{
            setSellFee();
        }

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tGrowthFund) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;
        _takeGrowthFund(tGrowthFund);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tGrowthFund) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _tOwned[recipient] = _tOwned[recipient] + tTransferAmount;
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;
        _takeGrowthFund(tGrowthFund);           
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tGrowthFund) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender] - tAmount;
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount; 
        _takeGrowthFund(tGrowthFund);  
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tGrowthFund) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender] - tAmount;
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _tOwned[recipient] = _tOwned[recipient] + tTransferAmount;
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;
        _takeGrowthFund(tGrowthFund);        
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function excludeFromFees(address account, bool excluded) external onlyOwner {
        require(_isExcludedFromFees[account] != excluded, "Account is already the value of 'excluded'");
        _isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }
    
    function changeGrowthFundWallet(address _growthFundWallet) external onlyOwner {
        require(_growthFundWallet != growthFundWallet, "GrowthFund wallet is already that address");
        require(_growthFundWallet!=address(0), "GrowthFund wallet is the zero address");
        growthFundWallet = _growthFundWallet;
        emit GrowthFundWalletChanged(growthFundWallet);
    }

    function setBuyFeePercentages(uint256 _taxFeeonBuy, uint256 _liquidityFeeonBuy, uint256 _growthFundFeeonBuy) external onlyOwner {
        taxFeeonBuy = _taxFeeonBuy;
        liquidityFeeonBuy = _liquidityFeeonBuy;
        growthFundFeeonBuy = _growthFundFeeonBuy;
        totalBuyFees = _taxFeeonBuy + _liquidityFeeonBuy + _growthFundFeeonBuy;
        require(totalBuyFees <= 10, "Buy fees cannot be greater than 10%");
        emit BuyFeesChanged(taxFeeonBuy, liquidityFeeonBuy, growthFundFeeonBuy);
    }

    function setSellFeePercentages(uint256 _taxFeeonSell, uint256 _liquidityFeeonSell, uint256 _growthFundFeeonSell) external onlyOwner {
        taxFeeonSell = _taxFeeonSell;
        liquidityFeeonSell = _liquidityFeeonSell;
        growthFundFeeonSell = _growthFundFeeonSell;
        totalSellFees = _taxFeeonSell + _liquidityFeeonSell + _growthFundFeeonSell;
        require(totalSellFees <= 10, "Sell fees cannot be greater than 10%");
        emit SellFeesChanged(taxFeeonSell, liquidityFeeonSell, growthFundFeeonSell);
    }

    function enableWalletToWalletTransferWithoutFee(bool enable) external onlyOwner {
        require(walletToWalletTransferWithoutFee != enable, "Wallet to wallet transfer without fee is already set to that value");
        walletToWalletTransferWithoutFee = enable;
        emit WalletToWalletTransferWithoutFeeEnabled(enable);
    }
}