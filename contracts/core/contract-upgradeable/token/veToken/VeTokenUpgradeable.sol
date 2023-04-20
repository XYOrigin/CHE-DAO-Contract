// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract VeTokenUpgradeable is
    Initializable,
    ContextUpgradeable,
    IERC20Upgradeable,
    IERC20MetadataUpgradeable
{
    struct Point {
        uint256 bias; // - 可以获得的veCRV数量总数
        uint256 slope; // 每秒可以获得的veCRV数量
        uint256 ts; // 质押开始时间
        uint256 blk; // 质押开始区块
    }

    struct LockedBalance {
        uint256 amount; // 锁定数量
        uint256 end; // 锁定结束时间
    }

    mapping(address => LockedBalance) private _locked; // 锁定的数量

    uint256 public constant WEEK = 7 * 86400; // all future times are rounded by week
    uint256 public constant MAXTIME = 4 * 365 * 86400; // 4 years
    uint256 public constant MULTIPLIER = 10 ** 18;

    uint256 private _currentEpoch; // 全局质押周期
    Point[] private _pointHistory; // 全局质押点

    mapping(address => Point[]) private _userPointHistory; // 用户质押点
    mapping(address => uint256) private _userPointEpoch; // 用户质押周期

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    IERC20MetadataUpgradeable private _tokenERC20;

    function __VeToken_init(
        IERC20MetadataUpgradeable tokenERC20_
    ) internal onlyInitializing {
        string memory name_ = string(
            abi.encodePacked("ve", tokenERC20_.name())
        );
        string memory symbol_ = string(
            abi.encodePacked("ve", tokenERC20_.symbol())
        );
        __VeToken_init_unchained(tokenERC20_, name_, symbol_);
    }

    function __VeToken_init_unchained(
        IERC20MetadataUpgradeable tokenERC20_,
        string memory name_,
        string memory symbol_
    ) internal onlyInitializing {
        _tokenERC20 = tokenERC20_;
        _name = name_;
        _symbol = symbol_;
        _decimals = tokenERC20_.decimals();
        _pointHistory.push(Point(0, 0, block.timestamp, block.number));
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function tokenERC20()
        public
        view
        virtual
        returns (IERC20MetadataUpgradeable)
    {
        return _tokenERC20;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return 0;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(
        address account
    ) public view virtual override returns (uint256) {
        return balanceOfAtTime(account, block.timestamp);
    }

    function balanceOfAtTime(
        address account,
        uint256 time
    ) public view virtual returns (uint256) {
        uint256 _epoch = _userPointEpoch[account];

        if (_epoch == 0) {
            return 0;
        } else {
            //check epoch in userPointHistory
            require(
                _userPointHistory[account][_epoch].ts <= time,
                "VeToken: time is not in the epoch"
            );

            Point memory lastPoint = _userPointHistory[account][_epoch];
            //需要销毁的ve数量
            uint256 _destroyAmount = lastPoint.slope * (time - lastPoint.ts);
            if (_destroyAmount >= lastPoint.bias) {
                lastPoint.bias = 0;
            } else {
                lastPoint.bias -= _destroyAmount;
            }
            return lastPoint.bias;
        }
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(
        address owner,
        address spender
    ) public view virtual override returns (uint256) {
        //not allow transfer
        require(spender == address(0), "VeToken: not allow transfer");
        require(owner == address(0), "VeToken: not allow transfer");
        return 0;
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(
        address spender,
        uint256 amount
    ) public virtual override returns (bool) {
        //not allow transfer
        require(spender == address(0), "VeToken: not allow transfer");
        require(amount > 0, "ERC20: transfer amount must be greater than zero");
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        //not allow transfer
        require(from == address(0), "VeToken: not allow transfer");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "ERC20: transfer amount must be greater than zero");
        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        //not allow transfer
        require(from == address(0), "VeToken: not allow transfer");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "ERC20: transfer amount must be greater than zero");
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[45] private __gap;
}
