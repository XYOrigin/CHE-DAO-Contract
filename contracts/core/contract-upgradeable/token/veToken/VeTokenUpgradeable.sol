// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract VeTokenUpgradeable is
    Initializable,
    ContextUpgradeable,
    IERC20Upgradeable,
    IERC20MetadataUpgradeable
{
    using SafeERC20Upgradeable for IERC20MetadataUpgradeable;

    struct Point {
        uint256 bias; // total amount of veCRV that can be obtained
        uint256 slope; // amount of veCRV that can be obtained per second
        uint256 ts; // lock start time
        uint256 blk; // lock start block
    }

    struct LockedBalance {
        uint256 amount; // locked amount
        uint256 end; // lock end time, second
    }

    event Deposit(
        address indexed user,
        uint256 amount,
        uint256 locktime,
        uint256 operatorType,
        uint256 blkTime
    );
    event Withdraw(address indexed user, uint256 amount, uint256 blkTime);
    event Supply(uint256 preSupply, uint256 supply);

    mapping(address => LockedBalance) private _userLockedBalance; // locked amount

    uint256 public constant WEEK = 7 * 86400; // all future times are rounded by week
    uint256 public constant MAXTIME = 4 * 365 * 86400; // 4 years
    uint256 public constant MULTIPLIER = 10 ** 18;

    uint256 public constant OPERATOR_TYPE_CREATE_LOCK = 0; // create lock
    uint256 public constant OPERATOR_TYPE_DEPOSIT = 1; // deposit

    uint256 private _currentEpoch; // global pledge cycle
    Point[] private _pointHistory; // global pledge point

    mapping(address => Point[]) private _userPointHistory; // user pledge point
    mapping(address => uint256) private _userPointEpoch; //  user pledge cycle

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    uint256 private _totalSupply;

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
        return _totalSupply;
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
            Point memory lastPoint = _userPointHistory[account][_epoch];
            require(lastPoint.ts <= time, "VeToken: time is not in the epoch");
            //the number of ve to be destroyed
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

    function lockedBalanceOf(
        address account
    ) public view virtual returns (LockedBalance memory) {
        return _userLockedBalance[account];
    }

    function createLock(uint256 amount, uint256 unlockTime) public virtual {
        uint256 unlockTime_ = (unlockTime / WEEK) * WEEK; //round to week

        LockedBalance memory lockedBalance_ = _userLockedBalance[_msgSender()];
        require(amount > 0, "VeToken: amount must be greater than zero");
        require(lockedBalance_.amount == 0, "VeToken: already have a lock");
        require(
            unlockTime_ > block.timestamp,
            "VeToken: unlock time must be greater than now"
        );
        require(
            unlockTime_ <= block.timestamp + MAXTIME,
            "VeToken: unlock time must be less than 4 year"
        );

        _deposit_for(
            _msgSender(),
            amount,
            unlockTime_,
            lockedBalance_,
            OPERATOR_TYPE_CREATE_LOCK
        );
    }

    function withdraw() public virtual {
        LockedBalance memory lockedBalance_ = _userLockedBalance[_msgSender()];
        require(
            lockedBalance_.amount > 0,
            "VeToken: no locked balance to withdraw"
        );
        require(
            lockedBalance_.end <= block.timestamp,
            "VeToken: locked balance is not unlock"
        );

        uint256 amount = lockedBalance_.amount;
        lockedBalance_.amount = 0;
        lockedBalance_.end = 0;

        _userLockedBalance[_msgSender()] = lockedBalance_;
        //update supply
        uint256 supplyBefore = _totalSupply;
        _totalSupply -= amount;

        //todo: check point

        //transfer token
        if (amount > 0) {
            _tokenERC20.safeTransfer(_msgSender(), amount);
        }

        emit Withdraw(_msgSender(), amount, block.timestamp);
        emit Supply(supplyBefore, _totalSupply);
    }

    function _deposit_for(
        address account,
        uint256 amount,
        uint256 unlockTime,
        LockedBalance memory lockedBalance,
        uint256 operatorType
    ) internal virtual {
        LockedBalance memory lockedBalance_ = lockedBalance;
        LockedBalance memory lockedBalanceBefore_ = lockedBalance;

        uint256 supplyBefore = _totalSupply;

        //update supply
        _totalSupply += amount;
        //update user locked balance
        lockedBalance_.amount += amount;
        if (unlockTime > 0) {
            lockedBalance_.end = unlockTime;
        }
        //update user locked balance
        _userLockedBalance[account] = lockedBalance_;

        //update user point
        //todo: add point

        //transfer token
        if (amount > 0) {
            _tokenERC20.safeTransferFrom(_msgSender(), address(this), amount);
        }

        emit Deposit(
            account,
            amount,
            lockedBalance_.end,
            operatorType,
            block.timestamp
        );

        emit Supply(supplyBefore, _totalSupply);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[45] private __gap;
}
