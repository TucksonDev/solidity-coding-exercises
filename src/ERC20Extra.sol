// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ERC20Extra {
    string public name;
    string public symbol;
    uint256 public totalSupply;

    // Note: packing these state variables to occupy one slot
    uint8 public decimals;
    address public minter;
    bool public paused;

    mapping(address => uint256) balances;

    // owner => spender => allowance
    mapping(address => mapping(address => uint256)) allowances;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approve(address indexed owner, address indexed spender, uint256 amount);

    // Errors
    error NotEnoughBalance();
    error NotEnoughAllowance();
    error MinterIsZero();
    error NotMinter();
    error Paused();
    error ZeroAmount();
    error TransferFromZero();
    error TransferToZero();
    error ApproveToZero();

    // Modifiers
    modifier onlyMinter() {
        if (msg.sender != minter) {
            revert NotMinter();
        }
        _;
    }

    modifier onlyUnPaused() {
        if (paused) {
            revert Paused();
        }
        _;
    }

    constructor(string memory _name, string memory _symbol, uint8 _decimals, address _minter) {
        if (_minter == address(0)) {
            revert MinterIsZero();
        }

        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        minter = _minter;
        paused = false;
    }

    /////////////////////////////////
    // Access controlled functions //
    /////////////////////////////////
    function mint(address to, uint256 amount) external onlyMinter {
        if (to == address(0)) {
            revert TransferToZero();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }

        balances[to] += amount;
        totalSupply += amount;

        emit Transfer(address(0), to, amount);
    }

    function pause() external onlyMinter onlyUnPaused {
        paused = true;
    }

    function unpause() external onlyMinter {
        paused = false;
    }

    /// @dev we allow transfering the role to the zero address
    function transferMinting(address _newMinter) external onlyMinter {
        minter = _newMinter;
    }

    ////////////////////////
    // Internal functions //
    ////////////////////////

    /// @dev this function only updates balances. Any check should be done in the functions calling this one
    function _transfer(address from, address to, uint256 amount) internal onlyUnPaused returns (bool) {
        if (balances[from] < amount) {
            revert NotEnoughBalance();
        }
        balances[from] -= amount;
        balances[to] += amount;
        return true;
    }

    //////////////////////
    // Public functions //
    //////////////////////

    /// @dev we allow transfers of amount 0
    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) {
            revert TransferToZero();
        }

        bool result = _transfer(msg.sender, to, amount);
        emit Transfer(msg.sender, to, amount);
        return result;
    }

    /// @dev we allow transfers of amount 0
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (from == address(0)) {
            revert TransferFromZero();
        }
        if (to == address(0)) {
            revert TransferToZero();
        }
        if (msg.sender != from) {
            if (allowances[from][msg.sender] < amount) {
                revert NotEnoughAllowance();
            }

            // Update allowances
            allowances[from][msg.sender] -= amount;
        }

        bool result = _transfer(from, to, amount);
        emit Transfer(from, to, amount);
        return result;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) {
            revert ApproveToZero();
        }
        allowances[msg.sender][spender] = amount;
        emit Approve(msg.sender, spender, amount);

        return true;
    }

    function burn(uint256 amount) external {
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (balances[msg.sender] < amount) {
            revert NotEnoughBalance();
        }

        balances[msg.sender] -= amount;
        totalSupply -= amount;

        emit Transfer(msg.sender, address(0), amount);
    }

    function balanceOf(address owner) external view returns (uint256) {
        return balances[owner];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return allowances[owner][spender];
    }
}
