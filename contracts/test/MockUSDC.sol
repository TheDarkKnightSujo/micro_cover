// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev Test-only 6-decimal token with a public mint.
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @dev Test-only token that burns 10% of every transfer (recipient receives less than sent).
contract FeeOnTransferUSDC is ERC20 {
    constructor() ERC20("Fee USDC", "fUSDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0) && value > 0) {
            uint256 fee = value / 10;
            super._update(from, address(0), fee);
            super._update(from, to, value - fee);
        } else {
            super._update(from, to, value);
        }
    }
}

/// @dev Test-only token that reverts on any transfer whose recipient is blocklisted.
contract BlocklistUSDC is MockUSDC {
    error Blocked(address account);

    mapping(address => bool) public blocked;

    function setBlocked(address account, bool value) external {
        blocked[account] = value;
    }

    function _update(address from, address to, uint256 value) internal override {
        if (blocked[to]) revert Blocked(to);
        super._update(from, to, value);
    }
}

/// @dev Test-only token that misbehaves on transfers sent by `feeFrom`.
/// SHORT: the recipient AND the sender's balance move by only 90% of the amount.
/// EXTRA: the full amount moves, plus an additional 10% burned from the sender.
contract OutgoingFeeUSDC is MockUSDC {
    enum Mode { OFF, SHORT, EXTRA }

    address public feeFrom;
    Mode public mode;

    function configure(address feeFrom_, Mode mode_) external {
        feeFrom = feeFrom_;
        mode = mode_;
    }

    function _update(address from, address to, uint256 value) internal override {
        if (mode != Mode.OFF && from == feeFrom && value > 0) {
            uint256 fee = value / 10;
            if (mode == Mode.SHORT) {
                super._update(from, to, value - fee);
            } else {
                super._update(from, to, value);
                super._update(from, address(0), fee);
            }
            return;
        }
        super._update(from, to, value);
    }
}

interface IRecipientHook {
    function tokensReceived(address from, uint256 amount) external;
}

/// @dev Test-only token that (a) calls `payload` on `target` whenever a transfer touches
/// `target` (excluding mints), and (b) optionally calls an ERC-777-style hook on contract
/// recipients of transfers sent by `target`.
contract ReentrantUSDC is MockUSDC {
    address public target;
    bytes public payload;
    bool public armed;
    bool public bubble;
    bool public hooksOn;
    uint256 public reentries;
    bool public lastOk;
    bytes public lastRet;

    function arm(address target_, bytes calldata payload_, bool bubble_) external {
        target = target_;
        payload = payload_;
        bubble = bubble_;
        armed = true;
        reentries = 0;
        lastOk = false;
        delete lastRet;
    }

    function disarm() external {
        armed = false;
    }

    function setHooks(address target_, bool on) external {
        target = target_;
        hooksOn = on;
    }

    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);
        if (armed && from != address(0) && (from == target || to == target)) {
            reentries++;
            (bool ok, bytes memory ret) = target.call(payload);
            lastOk = ok;
            lastRet = ret;
            if (!ok && bubble) {
                assembly {
                    revert(add(ret, 32), mload(ret))
                }
            }
        }
        if (hooksOn && from == target && to.code.length > 0) {
            IRecipientHook(to).tokensReceived(from, value);
        }
    }
}

/// @dev Test-only token for recipient-side fees: while enabled, a transfer sent by `feeFrom`
/// debits the sender in full but credits the recipient 10% less (the fee is burned).
/// If `feeTo` is nonzero only transfers to that recipient are affected. Toggle after enrolling.
contract RecipientFeeUSDC is MockUSDC {
    address public feeFrom;
    address public feeTo;
    bool public enabled;

    function configure(address feeFrom_, address feeTo_, bool enabled_) external {
        feeFrom = feeFrom_;
        feeTo = feeTo_;
        enabled = enabled_;
    }

    function _update(address from, address to, uint256 value) internal override {
        if (enabled && from == feeFrom && to != address(0) && value > 0 && (feeTo == address(0) || to == feeTo)) {
            uint256 fee = value / 10;
            super._update(from, address(0), fee);
            super._update(from, to, value - fee);
            return;
        }
        super._update(from, to, value);
    }
}
