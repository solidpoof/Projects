/**
 *Submitted for verification at Etherscan.io on 2024-04-30
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
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
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(
        address account
    ) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        if (currentAllowance != type(uint256).max) {
            require(
                currentAllowance >= amount,
                "ERC20: transfer amount exceeds allowance"
            );
            unchecked {
                _approve(sender, _msgSender(), currentAllowance - amount);
            }
        }

        _transfer(sender, recipient, amount);

        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(
            senderBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

interface IUniswapV2Factory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint
    );

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);

    function allPairs(uint) external view returns (address pair);

    function allPairsLength() external view returns (uint);

    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);

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

    function allowance(
        address owner,
        address spender
    ) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);

    function transfer(address to, uint value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint);

    function permit(
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(
        address indexed sender,
        uint amount0,
        uint amount1,
        address indexed to
    );
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

    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function price0CumulativeLast() external view returns (uint);

    function price1CumulativeLast() external view returns (uint);

    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);

    function burn(address to) external returns (uint amount0, uint amount1);

    function swap(
        uint amount0Out,
        uint amount1Out,
        address to,
        bytes calldata data
    ) external;

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
    )
        external
        payable
        returns (uint amountToken, uint amountETH, uint liquidity);

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
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
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

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function swapTokensForExactETH(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function quote(
        uint amountA,
        uint reserveA,
        uint reserveB
    ) external pure returns (uint amountB);

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountOut);

    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountIn);

    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);

    function getAmountsIn(
        uint amountOut,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
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
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
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

contract UPMAX is ERC20, Ownable {
    uint256 public constant pairDecimals = 18;
    uint256 public startTime;

    uint256 public treasuryFeeOnBuy = 250;
    uint256 public treasuryFeeOnSell = 250;
    uint256 public operationsFeeOnBuy = 250;
    uint256 public operationsFeeOnSell = 250;
    uint256 public EthToTreasury;
    uint256 public EthToOperations;

    uint256 private _totalFeesOnBuy = 500;
    uint256 private _totalFeesOnSell = 500;

    address public operationWallet = 0x3F534f03fa8cC16887c3defDcB5e41027c9D2523;
    address public treasuryWallet = 0x88C908c9e34DC0c98f08849eC36bf5738Ea6a5e4;
    address private creator = 0xd98ED1716e011EE5549FFCF10159bD25DfEd8Ade;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    address private DEAD = 0x000000000000000000000000000000000000dEaD;

    uint256 public swapTokensAtAmount;
    bool public swapEnabled = false;
    bool public swapWithLimit;
    bool private swapping;
    bool public tradingEnabled = false;

    mapping(address => bool) private _isExcludedFromFees;

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event UpdateBuyFees(uint256 treasuryFeeOnBuy, uint256 operationsFeeOnBuy);
    event UpdateSellFees(
        uint256 treasuryFeeOnSell,
        uint256 operationsFeeOnSell
    );
    event OperationWalletUpdated(address indexed newOperationWallet);
    event TreasuryWalletUpdated(address indexed newTreasuryWallet);
    event TradingEnabled(bool enabled);
    event WithdrawalEth(address indexed beneficiary, uint amount);
    event WithdrawalTokens(address indexed beneficiary, uint amount);

    constructor() ERC20("UPMAX", "MAX") {
        _isExcludedFromFees[owner()] = true;
        _isExcludedFromFees[DEAD] = true;
        _isExcludedFromFees[address(this)] = true;
        _isExcludedFromFees[creator] = true;
        _isExcludedFromFees[operationWallet] = true;
        _isExcludedFromFees[treasuryWallet] = true;

        _mint(owner(), 36_000_000 * (10 ** 18));
        swapTokensAtAmount = totalSupply() / 5000;
    }

    receive() external payable {}

    function initializePairAndLiquidity(
        address routerAddress
    ) external onlyOwner {
        require(
            address(uniswapV2Router) == address(0),
            "Router already initialized"
        );

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(routerAddress);
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;

        _approve(address(this), address(uniswapV2Router), type(uint256).max);

        uniswapV2Router.addLiquidityETH{value: address(this).balance}(
            address(this),
            balanceOf(address(this)),
            0,
            0,
            owner(),
            block.timestamp
        );
    }

    function excludeFromFees(address account) external onlyOwner {
        require(
            _isExcludedFromFees[account] != true,
            "Account is already the value of 'excluded'"
        );
        _isExcludedFromFees[account] = true;

        emit ExcludeFromFees(account, true);
    }

    function includeInFees(address account) external onlyOwner {
        require(
            _isExcludedFromFees[account] != false,
            "Account is already the value of 'included'"
        );
        _isExcludedFromFees[account] = false;

        emit ExcludeFromFees(account, false);
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function getEthToTreasury() public view returns (uint256) {
        return EthToTreasury;
    }

    function getEthToOperations() public view returns (uint256) {
        return EthToOperations;
    }

    function updateBuyFees(
        uint256 _treasuryFeeOnBuy,
        uint256 _operationsFeeOnBuy
    ) external onlyOwner {
        require(
            _treasuryFeeOnBuy + _operationsFeeOnBuy <= 1500,
            "Fees must be less than 15%"
        );
        treasuryFeeOnBuy = _treasuryFeeOnBuy;
        operationsFeeOnBuy = _operationsFeeOnBuy;
        _totalFeesOnBuy = treasuryFeeOnBuy + operationsFeeOnBuy;
        emit UpdateBuyFees(_treasuryFeeOnBuy, _operationsFeeOnBuy);
    }

    function updateSellFees(
        uint256 _treasuryFeeOnSell,
        uint256 _operationsFeeOnSell
    ) external onlyOwner {
        require(
            _treasuryFeeOnSell + _operationsFeeOnSell <= 1500,
            "Fees must be less than 15%"
        );
        treasuryFeeOnSell = _treasuryFeeOnSell;
        operationsFeeOnSell = _operationsFeeOnSell;
        _totalFeesOnSell = treasuryFeeOnSell + operationsFeeOnSell;
        emit UpdateSellFees(_treasuryFeeOnSell, _operationsFeeOnSell);
    }

    function changeOperationWallet(
        address _operationWallet
    ) external onlyOwner {
        require(
            _operationWallet != address(0),
            "Operation wallet cannot be zero address"
        );
        operationWallet = _operationWallet;
        emit OperationWalletUpdated(_operationWallet);
    }

    function changeTreasuryWallet(address _treasuryWallet) external onlyOwner {
        require(
            _treasuryWallet != address(0),
            "Operation wallet cannot be zero address"
        );
        treasuryWallet = _treasuryWallet;
        emit TreasuryWalletUpdated(_treasuryWallet);
    }

    function enableTrading() external onlyOwner {
        require(!tradingEnabled, "Trading is already enabled");
        require(balanceOf(uniswapV2Pair) > 0, "Liquidity must be added first");
        tradingEnabled = true;
        startTime = block.timestamp;
        swapEnabled = true;
        emit TradingEnabled(true);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        if (!_isExcludedFromFees[from] && !_isExcludedFromFees[to]) {
            require(tradingEnabled == true, "Trading is not enabled yet");
        }

        uint256 contractTokenBalance = balanceOf(address(this));

        bool canSwap = contractTokenBalance >= swapTokensAtAmount;

        if (
            swapEnabled &&
            canSwap &&
            !swapping &&
            to == uniswapV2Pair &&
            _totalFeesOnBuy + _totalFeesOnSell > 0
        ) {
            swapping = true;

            if (swapWithLimit) {
                contractTokenBalance = swapTokensAtAmount;
            }

            uint256 totalFee = _totalFeesOnBuy + _totalFeesOnSell;
            uint256 treasuryShare = treasuryFeeOnBuy + treasuryFeeOnSell;
            uint256 operationsShare = operationsFeeOnBuy + operationsFeeOnSell;

            if (contractTokenBalance > 0 && swapEnabled) {
                address[] memory path = new address[](2);
                path[0] = address(this);
                path[1] = uniswapV2Router.WETH();

                uniswapV2Router
                    .swapExactTokensForETHSupportingFeeOnTransferTokens(
                        contractTokenBalance,
                        0,
                        path,
                        address(this),
                        block.timestamp
                    );

                uint256 newBalance = address(this).balance;

                if (treasuryShare > 0) {
                    uint256 treasuryAmount = (newBalance * treasuryShare) /
                        totalFee;
                    (bool sent, ) = treasuryWallet.call{value: treasuryAmount}(
                        ""
                    );
                    require(sent, "Send Failed");
                    EthToTreasury += treasuryAmount;
                }

                if (operationsShare > 0) {
                    uint256 operationsAmount = address(this).balance;
                    (bool sent, ) = operationWallet.call{
                        value: operationsAmount
                    }("");
                    require(sent, "Send failed");
                    EthToOperations += operationsAmount;
                }
            }

            swapping = false;
        }

        bool takeFee = !swapping;

        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        if (takeFee && (from == uniswapV2Pair || to == uniswapV2Pair)) {
            uint256 _totalFees;
            if (from == uniswapV2Pair) {
                _totalFees = _totalFeesOnBuy;
            } else if (to == uniswapV2Pair) {
                _totalFees = _totalFeesOnSell;
            }
            uint256 fees = (amount * _totalFees) / 10000;

            amount = amount - fees;

            if (fees > 0) {
                super._transfer(from, address(this), fees);
            }
        }

        super._transfer(from, to, amount);
    }

    function setSwapEnabled(bool _swapEnabled) external onlyOwner {
        require(
            swapEnabled != _swapEnabled,
            "Swap is already set to that state"
        );
        swapEnabled = _swapEnabled;
    }

    function setSwapTokensAtAmount(uint256 newAmount) external onlyOwner {
        require(
            newAmount > totalSupply() / 1_000_000,
            "New Amount must more than 0.0001% of total supply"
        );
        swapTokensAtAmount = newAmount;
    }

    function setSwapWithLimit(bool _swapWithLimit) external onlyOwner {
        require(
            swapWithLimit != _swapWithLimit,
            "Swap with limit is already set to that state"
        );
        swapWithLimit = _swapWithLimit;
    }

    function Multisend(
        address[] memory addresses,
        uint256[] memory amounts
    ) external onlyOwner {
        require(addresses.length == amounts.length, "Arrays must be equal");
        uint256 totalAmount;

        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        require(balanceOf(msg.sender) >= totalAmount, "Not enough tokens");

        for (uint256 i = 0; i < addresses.length; i++) {
            _transfer(_msgSender(), addresses[i], amounts[i]);
        }
    }

    function withdraw(address _beneficiary) external onlyOwner {
        uint256 amount = address(this).balance;
        require(amount > 0, "No Tokens to withdraw");
        (bool sent, ) = _beneficiary.call{value: amount}("");
        require(sent, "Send Failed");

        emit WithdrawalEth(_beneficiary, amount);
    }

    function withdrawToken(
        address _beneficiary,
        address _token
    ) external onlyOwner {
        uint256 amount = IERC20(_token).balanceOf(address(this));
        require(amount > 0, "No Tokens to withdraw");
        IERC20(_token).transfer(_beneficiary, amount);

        emit WithdrawalTokens(_beneficiary, amount);
    }
}