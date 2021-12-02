pragma solidity ^0.6.0;

contract Auction {
    enum State { Ready, Initialized, Pending, Settled, Violated, Successful, Canceled }
    State public AuctionState;
    event AuctionStateModified(address indexed _who, uint _time, State _newstate);
    event SLAContractsGenerated(address indexed _who, uint _time, address[] _contractAddr);

    uint256 public number;
    uint public startTime;
    uint public setupEnd;
    uint public registeEnd;
    uint public biddingEnd;
    uint public revealEnd;
    uint public withdrawEnd;
    uint public serviceStart;
    uint public serviceEnd;

    constructor(uint _setupTime, uint _registeTime, uint _biddingTime, uint _revealTime, uint _withdrawTime, uint _serviceTime) 
        public 
    {
        
        require (_setupTime > 0);
        require (_registeTime > 0);
        require (_biddingTime > 0);
        require (_revealTime > 0);
        require (_withdrawTime > 0);
        require (_serviceTime > 0);
     
        startTime = now;
        setupEnd = startTime + _setupTime;
        registeEnd = setupEnd + _registeTime;
        biddingEnd = registeEnd + _biddingTime;
        revealEnd = biddingEnd + _revealTime;
        withdrawEnd = revealEnd + _withdrawTime;

        serviceStart = withdrawEnd + 1 days;
        serviceEnd = serviceStart + _serviceTime;

    }

    struct AuctionItem {
        string cutomerName;
        bytes32 sealedReservePrice;
        string auctionDetails;
        uint witnessFee; 
        uint8 providerNumber;
        uint8 witnessNumber;
    }
    mapping(address => AuctionItem) public auctionItemStructs;
    address payable [] public customerAddresses;
    uint public unitWitnessFee = 1e17;      // To ensure each witness tell the truth, unitWitnessFee should weakly balanced with Epsilon * providerNumber.


    /**
     * Customer Interface:
     * This is for customer to 1) setup the auction, 2) publish the auction details, and 3) prepay the witnessfee
     * */
    function setupAuction (string memory _customerName, string memory _auctionDetails, bytes32 _sealedReservePrice, uint8 _providerNumber, uint8 _witnessNumber) 
        public
        payable
        // checkTimeAfter(startTime)
        // checkTimeBefore(setupEnd)
        returns(bool setupAuctionSuccess)
    {
        require (_sealedReservePrice.length != 0 && bytes(_auctionDetails).length > 0);
        require (customerAddresses.length >= 0);
        require (msg.value >=  (_witnessNumber * unitWitnessFee) / 2 );
        auctionItemStructs[msg.sender].cutomerName = _customerName;
        auctionItemStructs[msg.sender].sealedReservePrice = _sealedReservePrice;
        auctionItemStructs[msg.sender].auctionDetails = _auctionDetails;
        auctionItemStructs[msg.sender].providerNumber = _providerNumber;
        auctionItemStructs[msg.sender].witnessNumber = _witnessNumber;
        auctionItemStructs[msg.sender].witnessFee = msg.value;
        customerAddresses.push(msg.sender);
        return true;        
    }

    struct Bidder {
        uint index; // the id of the provider in the address pool
        bool registered;    ///true: this provider has registered     
    }
    mapping (address => Bidder) public providerPool;
    address [] public providerAddrs;    ////the address pool of providers, which is used for register new providers in the auction
    
    /**
     * Provider Interface:
     * This is for normal user register as providers(bidders) to participant the auction
     * */
    function bidderRegister () 
        public
        // checkTimeAfter(setupEnd)
        // checkTimeBefore(registeEnd)
        returns(bool registerSuccess) 
    {
        require (providerPool[msg.sender].registered == false);
        providerPool[msg.sender].index = providerAddrs.length;
        providerPool[msg.sender].registered = true;
        providerAddrs.push(msg.sender);
        return true;
    }
    
    function checkProviderNumber () 
        public
    {
        if (providerAddrs.length >= auctionItemStructs[customerAddresses[0]].providerNumber){
            AuctionState = State.Initialized;
            emit AuctionStateModified(msg.sender, now, State.Initialized);
        } else {
            AuctionState = State.Canceled;
            emit AuctionStateModified(msg.sender, now, State.Canceled);
        }
    }
    struct Bid {
        string providerName;
        bytes32 sealedBid;
        uint witnessFee;
    }
    mapping(address => Bid) public bidStructs;
    address [] public bidderAddresses;

    /**
     * Provider Interface:
     * This is for registered providers to 1) submit sealed bids and 2) prepay the witness fee
     * */
    function submitBids(string memory _providerName, bytes32 _sealedBid) 
        public
        payable
        // checkTimeAfter(registeEnd)
        // checkTimeBefore(biddingEnd)
        returns(bool submitSuccess)
    {
        require (_sealedBid.length != 0 && bytes(_providerName).length > 0);   
        require (bidderAddresses.length <= 200);
        // require (msg.value >=  (auctionItemStructs[customerAddresses[0]].witnessNumber * unitWitnessFee) / (2 * auctionItemStructs[customerAddresses[0]].providerNumber) );
        bidStructs[msg.sender].sealedBid = _sealedBid;
        bidStructs[msg.sender].providerName = _providerName;
        bidStructs[msg.sender].witnessFee = msg.value;
        bidderAddresses.push(msg.sender);
        return true;
    }

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// phase6: customer reveal the reserve price
    uint public reservePrice;

    /**
     * Customer Interface:
     * This is for customer to reveal the reserve price
     * */
    function revealReservePrice (string memory _customerName, uint _reservePrice, uint _customerKey)
        public
        payable
        // checkState(State.Initialized)
        // checkTimeAfter(biddingEnd)
        // checkTimeBefore(revealEnd)
        returns(uint)
    {
        require (_reservePrice > 0 && _customerKey != 0);
        // require (keccak256(abi.encodePacked(auctionItemStructs[msg.sender].cutomerName)) == keccak256(abi.encodePacked(_customerName)));
        // require (bidderAddresses.length >= auctionItemStructs[customerAddresses[0]].providerNumber && customerAddresses.length == 1);
        if (keccak256(abi.encodePacked(_reservePrice, _customerKey)) == auctionItemStructs[msg.sender].sealedReservePrice){
            reservePrice = _reservePrice;
        }
        return reservePrice;
    }
    address payable [] public revealedBidders;
    uint [] public revealedBids;
    
    /**
     * Provider Interface:
     * This is for registered providers(who submitted the sealed bid) to reveal the bid
     * */
    function revealBids (string memory _providerName, uint _bid, uint _providerKey)
        public
        payable
        // checkTimeAfter(biddingEnd)
        // checkTimeBefore(revealEnd)
    {
        // require (_bid > 0 && _providerKey != 0);
        // require (keccak256(abi.encodePacked(bidStructs[msg.sender].providerName)) == keccak256(abi.encodePacked(_providerName)));
        if (keccak256(abi.encodePacked(_bid, _providerKey)) == bidStructs[msg.sender].sealedBid){
            // revealedBids[msg.sender] = _bid;
            revealedBidders.push(msg.sender);
            revealedBids.push(_bid);
        }
    }
    address payable [] public winnerBidders;
    address payable [] public loserBidders;
    uint [] public winnerBids;
    uint [] public loserBids;
    mapping(address => uint) refund;

    // set the addresses in store
    function setTest (address payable [] memory _addresses, uint [] memory _bid, uint _reserve) public {
        revealedBidders = _addresses;
        revealedBids = _bid;
        reservePrice = _reserve;
    }

    function getTesBidders () public view returns(address payable [] memory){
        return revealedBidders;
    }
    function getTestBids () public view returns(uint [] memory){
        return revealedBids;
    }
    /**
     * Customer Interface:
     * This is for customer to 1) sort the bids by ascending 2) select k-th providers to form a federated cloud servcie
     * */        
    function placeBids () 
        public
        // checkTimeAfter(revealEnd)
        // checkTimeBefore(withdrawEnd)
        returns(address payable [] memory, address payable [] memory)
    {

        // require (revealedBidders.length >= auctionItemStructs[customerAddresses[0]].providerNumber);
        bool exchanged; 
        for (uint i=0; i < revealedBids.length - 1; i++) {
            exchanged = false;
            for (uint j =0; j < revealedBids.length- i - 1; j++){
                if (revealedBids[j] > revealedBids[j+1]){
                    (revealedBids[j], revealedBids[j+1]) = (revealedBids[j+1], revealedBids[j]);
                    (revealedBidders[j], revealedBidders[j+1]) = (revealedBidders[j+1], revealedBidders[j]);
                    exchanged = true;
                }
            }
                if(exchanged==false) break;
        }

        uint sumBids;
        for(uint i=0; i < auctionItemStructs[customerAddresses[0]].providerNumber; i++){
            sumBids += revealedBids[i];
        }
        
        for (uint i=0; i < revealedBidders.length; i++) {
            if( i< auctionItemStructs[customerAddresses[0]].providerNumber && sumBids <= reservePrice) {
                winnerBids.push() = revealedBids[i];
                winnerBidders.push() = revealedBidders[i];
            } else if( i >= auctionItemStructs[customerAddresses[0]].providerNumber && sumBids <= reservePrice ){
                loserBids.push() = revealedBids[i];
                loserBidders.push() = revealedBidders[i];
            } else if( sumBids > reservePrice ){
                loserBids.push() = revealedBids[i];
                loserBidders.push() = revealedBidders[i];
            }
        }
        if (winnerBidders.length == auctionItemStructs[customerAddresses[0]].providerNumber){
            AuctionState = State.Pending;
            emit AuctionStateModified(msg.sender, now, State.Pending);
        } else if (winnerBidders.length == 0){
            AuctionState = State.Canceled;
            emit AuctionStateModified(msg.sender, now, State.Canceled);
        }
        return (winnerBidders,loserBidders);
    }


    function providerWithdrawWitnessFee()
        public  
        // checkTimeAfter(revealEnd)
        // checkTimeBefore(withdrawEnd)
        returns(bool withdrawSuccess)
    { 
        // require (bidStructs[msg.sender].witnessFee > 0);
        // require (loserBidders.length != 0);
        for (uint i=0; i < loserBidders.length; i++) {
            if (loserBidders[i] == msg.sender){
            refund[msg.sender] = bidStructs[msg.sender].witnessFee;
            msg.sender.transfer(refund[msg.sender]);
            bidStructs[msg.sender].witnessFee = 0;
            return true;
            }
        }        
    }
    function customerWithdrawWitnessFee()
        public  
        // checkTimeAfter(revealEnd)
        // checkTimeBefore(withdrawEnd)
        returns(bool withdrawSuccess)
    {
        // require (auctionItemStructs[msg.sender].witnessFee >= 0);
        if (winnerBidders.length == 0) {
            refund[msg.sender] = auctionItemStructs[msg.sender].witnessFee;
            msg.sender.transfer(refund[msg.sender]);
            auctionItemStructs[msg.sender].witnessFee = 0;         
        }
        return true;
    }
    struct ContractInfo {
    uint index; // the id of the SLA contract in the address pool
    uint serviceFee; // the service fee should be the bidding price
    bool accepted; // true: this contract has been accepted
    }    
    mapping(address => ContractInfo) public SLAContractPool;
    address [] public SLAContractAddresses;

    
    // function genSLAContract() 
    //     public
    //     payable
    //     // checkTimeBefore(serviceStart)
    //     returns(address[] memory)
        
    // {
    //     require ( winnerBidders.length > 0);   
    //     for (uint i=0; i < winnerBidders.length; i++) {
    //         address newSLAContract = address (new CloudSLA(this, winnerBidders[i], msg.sender, auctionItemStructs[msg.sender].auctionDetails, winnerBids[i]));
    //         SLAContractPool[newSLAContract].index = SLAContractAddresses.length;
    //         SLAContractPool[newSLAContract].serviceFee = winnerBids[i];
    //         SLAContractAddresses.push(newSLAContract);
    //     }
    //     uint totalBids;
    //     for (uint i=0; i < winnerBids.length; i++) {
    //         totalBids += winnerBids[i];
    //     }
    //     require (msg.value == totalBids);

    //     if (SLAContractAddresses.length == winnerBidders.length){
    //         emit SLAContractsGenerated(msg.sender, now, SLAContractAddresses);
    //         return SLAContractAddresses;
    //     }
    // }

    function acceptSLA() 
        public 
        payable 
        // checkTimeBefore(serviceStart)
    {   
        // require (SLAContractAddresses.length == winnerBidders.length);   
        for (uint i=0; i < winnerBidders.length; i++) {
            if (winnerBidders[i] == msg.sender){
            SLAContractPool[SLAContractAddresses[i]].accepted = true;
            }
        }
    }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// phase13: normal user register as Witnesses and monitor the federated Cloud service.
    struct Witness {
        uint index;         ///the index of the witness in the address pool, if it is registered
        bool registered;    ///true: this witness has registered.
        address[] SLAContracts;    ////the address of SLA contract
    }
    mapping(address => Witness) public witnessPool;
    address [] public witnessAddrs;    ////the address pool of witnesses

    /**
     * Witness Interface:
     * This is for normal users register as witnesses to monitor the federated Cloud service
     * */
    function witnessRegister()
        public
        // checkTimeAfter(revealEnd)
        // checkTimeBefore(serviceStart)
        returns(bool registerSuccess)
    {
        // require (witnessAddrs.length <= 100);
        // require (witnessPool[msg.sender].registered == false);
        witnessPool[msg.sender].index = witnessAddrs.length;
        witnessPool[msg.sender].registered = true;
        witnessPool[msg.sender].SLAContracts = SLAContractAddresses;
        witnessAddrs.push(msg.sender);
        return true;
    }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// phase14: customer to check the whether the registered witnesses number is enough && all SLAs has been signed 
    /**
     * Customer Interface:
     * This is for customer to check the whether the registered witnesses number is enough && all SLAs has been signed 
     * */
    function checkAuctionSettled () 
        public
    {   
        uint counter;
        for (uint i=0; i < SLAContractAddresses.length; i++) {
            if (SLAContractPool[SLAContractAddresses[i]].accepted = true) {
                counter++;
            }
        }   
        if (witnessAddrs.length >= auctionItemStructs[customerAddresses[0]].witnessNumber && counter == SLAContractAddresses.length){
            AuctionState = State.Settled;
            emit AuctionStateModified(msg.sender, now, State.Settled);
        } else {
            AuctionState = State.Canceled;
            emit AuctionStateModified(msg.sender, now, State.Canceled);
        }
    }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  
}



contract Witness {


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// phase15: registered witnesses submit sealed monitoring messages.
    mapping (address => bytes32[]) sealedMessageArray;

    /**
     * Witness Interface:
     * This is for registered witnesses to submit the (sealed) monitoring messages array for different SLAs in the federated cloud service
     * */
    function submitMessages(bytes32[] memory _sealedMessage) 
        public
        payable
        // checkTimeAfter(serviceEnd)
        returns(bool reportSuccess)
    {   
        // require (witnessPool[msg.sender].registered = true);       
        // require (_sealedMessage.length == auctionItemStructs[customerAddresses[0]].providerNumber);   
        sealedMessageArray[msg.sender] = _sealedMessage;
        return true;
    }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// phase16: registered witnesses reveal sealed messages.
    mapping (address => uint[]) public revealedMessageArray;
    address payable [] public revealedWitnesses; 

    /**
     * Witness Interface:
     * This is for registered witnesses(who submitted the sealed messages) to reveal the message array
     * */
    function revealMessages (uint[] memory _message, uint _witnessKey)
        public
        payable
        // checkTimeAfter(serviceEnd)
        returns(bool revealSuccess)
    {
        // require (_message.length == auctionItemStructs[customerAddresses[0]].providerNumber && _witnessKey != 0);
        uint SLAsNumber;
        for (uint i=0; i < auctionItemStructs[customerAddresses[0]].providerNumber; i++) {
            // check all the monitoring messages (for k SLAs) in the rang 0-10.
            // require (_message[i] >= 0 && _message[i] <= 10);
            if (keccak256(abi.encodePacked(_message[i], _witnessKey)) == sealedMessageArray[msg.sender][i]){
                SLAsNumber++;
            }
        }
        // check all the monitoring messages(for k SLAs) in the array reveled successfully.
        if (SLAsNumber == auctionItemStructs[customerAddresses[0]].providerNumber) {
            revealedMessageArray[msg.sender] = _message;
            revealedWitnesses.push(msg.sender);
            return true;
        } else if (SLAsNumber < auctionItemStructs[customerAddresses[0]].providerNumber) {
            return false;
        }
    }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// phase17: customer calculate and place the witness fee
    uint public Epsilon = 4;
    mapping (address => uint) public witnessFee;

    // mapping (address => uint[]) public revealedMessageArray;
    // address payable [] public revealedWitnesses; 

    // function addRevealedMessageArray (uint[] memory _revealedMessageArray) 
    //     public
    // {
    //     revealedMessageArray[msg.sender] = _revealedMessageArray;
    //     revealedWitnesses.push(msg.sender);
    // }
   
    /**
     * Customer Interface:
     * This is for customer to calculate the wisness fee for all the witnesses based on their report result
     * */ 
    function calculateWitnessFee ()
        public
        // checkTimeAfter(serviceEnd)
        returns(bool calculateSuccess)
    {

        // require (revealedWitnesses.length == auctionItemStructs[customerAddresses[0]].witnessNumber);
        
        for (uint i=0; i < revealedWitnesses.length; i++) {
            uint accumulator = 0;
            for (uint j=0; j < auctionItemStructs[customerAddresses[0]].providerNumber; j++) {
                for (uint k=0; k < revealedWitnesses.length; k++) {
                    // here need to check the divide accuracy of solidity version
                    accumulator += (revealedMessageArray[revealedWitnesses[i]][j] - revealedMessageArray[revealedWitnesses[k]][j]) ** 2;
                }
            }
            witnessFee[revealedWitnesses[i]] = unitWitnessFee - accumulator * Epsilon / (revealedWitnesses.length - 1);
        }
        return true;
    }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// phase18: witnesses withdraw the witness fee
    /**
     * Witness Interface:
     * This is for registered witnesses to withdraw the witness fee (if the message array is revealed successfully)
     * */ 
    function witnessWithdraw()
        public
        // checkTimeAfter(serviceEnd)
        returns(bool withdrawSuccess)
    {
        // require(witnessFee[msg.sender] > 0);
        msg.sender.transfer(witnessFee[msg.sender]);
        witnessFee[msg.sender] = 0;
        return true;
    }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


    
    // for debug
    // address payable [] public SLAContractAddresses;
    // mapping (address => uint[]) public revealedMessageArray;
    // address payable [] public revealedWitnesses; 
    // mapping (address => bool) public SLAViolated;
    // address [] public SLAViolatedAddresses;
    // address payable [] public winnerBidders;
    // uint [] public winnerBids;
    // struct ContractInfo {
    //     uint index; // the id of the SLA contract in the address pool
    //     uint serviceFee; // the service fee should be the bidding price
    //     bool accepted; // true: this contract has been accepted
    // }    
    // mapping(address => ContractInfo) SLAContractPool;
    
    // function addRevealedMessageArray(uint[] memory _revealedMessageArray) public { 
    //     revealedMessageArray[msg.sender] = _revealedMessageArray;
    //     revealedWitnesses.push () = msg.sender;
    // }
    
    // function addSLAContractAddresses() public {
    //     SLAContractAddresses.push () = msg.sender;
    // }
    

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// phase20: customer withdraw the service fee
    /**
     * Customer Interface:
     * This is for customer to withdraw the service fee (if the SLA[j] is violated)
     * */ 
    function customerWithdrawServiceFee()
        public
        // checkTimeAfter(serviceEnd)
        returns(bool withdrawSuccess)

    {
        for (uint i=0; i < SLAContractAddresses.length; i++) {
            if (SLAViolated[SLAContractAddresses[i]] == true) {
                msg.sender.transfer(SLAContractPool[SLAContractAddresses[i]].serviceFee);
                SLAContractPool[SLAContractAddresses[i]].serviceFee = 0;
            }
        }
        return true;
    }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// phase21: provider withdraw the service fee
    /**
     * Provider Interface:
     * This is for provider to withdraw the service fee (if the SLA[j] is not violated)
     * */ 
    function providerWithdrawServiceFee()
        public
        payable
        // checkTimeAfter(serviceEnd)
        returns(bool withdrawSuccess)
    {
        if (AuctionState == State.Successful || AuctionState == State.Violated){
            for (uint i=0; i < SLAContractAddresses.length; i++) {
                if (winnerBidders[i] == msg.sender && SLAViolated[SLAContractAddresses[i]] == false){
                    msg.sender.transfer(SLAContractPool[SLAContractAddresses[i]].serviceFee);
                    SLAContractPool[SLAContractAddresses[i]].serviceFee = 0;
                    return true;
                }
            }
        }
    }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

}

contract SLA {

    string public cloudServiceDetail = "";
    
    address public customer;
    address public provider;
    CloudAuction public MainContract;
    string public serviceDetail;
    uint public serviceFee;

    constructor(CloudAuction _auctionManagement, address _provider, address _customer, string memory _serviceDetail, uint _serviceFee)
        public
    {
        provider = _provider;
        customer = _customer;
        MainContract = _auctionManagement;
        serviceDetail = _serviceDetail;
        serviceFee = _serviceFee;
    }


    function publishService(string memory _serviceDetail) 
        public 
        // checkState(State.Fresh) 
        // checkProvider
    {
        cloudServiceDetail = _serviceDetail;
    }

    uint WitnessNumber = 10;
    uint ProviderBalance = 0;
    enum State { Fresh, Init, Active, Violated, Completed }
    State public SLAState;
    uint AcceptTimeEnd = 0;
    uint AcceptTimeWin = 2 minutes;   ///the time window for waiting the customer to accept this SLA, otherwise the state of SLA is transferred to Completed
    ////this is to log event that _who modified the SLA state to _newstate at time stamp _time
    event SLAStateModified(address indexed _who, uint _time, State _newstate);
    
    


    function setupSLA() 
        public 
        payable 
        // checkState(State.Fresh) 
        // checkProvider
        // checkMoney(PPrepayment)
    {
        require(WitnessNumber == 10);
        ProviderBalance += msg.value;
        SLAState = State.Init;
        AcceptTimeEnd = now + AcceptTimeWin;
        emit SLAStateModified(msg.sender, now, State.Init);
    }

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// phase22: customer reset the auction
    /**
     * Customer Interface:
     * This is for customer to reset the auction to Ready state
     * */ 
    function resetSLA()
        public
        // checkReset()
        // checkTimeAfter(serviceEnd)
        // checkCustomer(msg.sender)
    {
        delete winnerBidders;
        delete winnerBids;
        delete loserBidders;
        delete loserBids;
        AuctionState = State.Ready;
        emit AuctionStateModified(msg.sender, now, State.Ready);
    }

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// phase19: customer check SLA violation and place the service fee 
    mapping (address => bool) public SLAViolated;
    address [] public SLAViolatedAddresses;

    /**
     * Customer Interface:
     * This is for customer to check the SLA violation result and place the service fee 
     * */ 
    function checkSLAViolation ()
        public
        payable
        // checkTimeAfter(serviceEnd)
        returns(bool checkSuccess)
    {   
        uint counter;
        for (uint j=0; j < SLAContractAddresses.length; j++) {
            for (uint i=0; i < revealedWitnesses.length; i++) {
                // The message space is [1,10], the mean is 5
                if (revealedMessageArray[revealedWitnesses[i]][j] > 5) {
                    counter ++; 
                }
            }
            if (counter > revealedWitnesses.length/2) {
                SLAViolated[SLAContractAddresses[j]] = true;
                SLAViolatedAddresses.push() = SLAContractAddresses[j];
            } else if (counter <= revealedWitnesses.length/2) {
                SLAViolated[SLAContractAddresses[j]] = false;
            }
            counter = 0;
        }              
        for (uint j=0; j < SLAContractAddresses.length; j++) {
            if (SLAViolatedAddresses.length == 0){
                AuctionState = State.Successful;
                emit AuctionStateModified(msg.sender, now, State.Successful);
            } else if (SLAViolatedAddresses.length != 0) {
                AuctionState = State.Violated;
                emit AuctionStateModified(msg.sender, now, State.Violated);
        }
        }
        return true;   
    }


}



// pragma solidity ^0.6.0;

// contract CloudAuction {
    
//     uint SLAs = 3;
//     uint Witnesses = 5;
//     mapping (address => bytes32[]) public sealedMessageArray;
//     mapping (address => uint[]) public revealedMessageArray;

//     mapping (address => uint256) public submissionDeposit;

//     uint public witnessNum;
//     uint public revealWitnessNum;
    
//     function submitMessages(bytes32[] memory _sealedMessage) 
//         public
//         payable
//         // checkTimeAfter(serviceEnd)
//         returns(bool reportSuccess)
//     {   
//         // require (witnessPool[msg.sender].registered = true);       
//         require (_sealedMessage.length == SLAs);   
//         require (msg.value >  0 );
//         sealedMessageArray[msg.sender] = _sealedMessage;
//         submissionDeposit[msg.sender] = msg.value;
//         witnessNum++;
//         if (witnessNum == Witnesses) {
//             return true;
//         } 
//     }
    
    
//     function revealMessages (uint[] memory _message, uint _witnessKey)
//         public
//         payable
//         // checkTimeAfter(serviceEnd)
//         returns(bool revealSuccess)
//     {
//         uint SLAsNum;
//         require (_message.length == SLAs && _witnessKey != 0);
//         for (uint i=0; i < SLAs; i++) {
//             // check all the monitoring messages (for k SLAs) in the rang 0-10.
//             require (_message[i] >= 0 && _message[i] <= 10);
//             if (keccak256(abi.encodePacked(_message[i], _witnessKey)) == sealedMessageArray[msg.sender][i]){
//                 SLAsNum++;
//             }
//         }
//         if (SLAsNum == SLAs) {
//             revealedMessageArray[msg.sender] = _message;
//             msg.sender.transfer(submissionDeposit[msg.sender]);
//             submissionDeposit[msg.sender] = 0;
//             revealWitnessNum ++;      
//             if (revealWitnessNum == Witnesses) {
//                 return true;
//             } 
//         } 
//     }





/**
 * The contractName contract does this and that...
 */
contract Factory {


    function genSLAContract() 
        public
        payable
        checkState(State.Pending)
        checkTimeBefore(serviceStart)
        checkCustomer(msg.sender)
        returns(address[] memory)
        
    {
        require ( winnerBidders.length > 0);   
        for (uint i=0; i < winnerBidders.length; i++) {
            address newSLAContract = address (new SLA(this, winnerBidders[i], msg.sender, auctionItemStructs[msg.sender].auctionDetails, winnerBids[i]));
            SLAContractPool[newSLAContract].index = SLAContractAddresses.length;
            SLAContractPool[newSLAContract].serviceFee = winnerBids[i];
            SLAContractAddresses.push(newSLAContract);
        }
        uint totalBids;
        for (uint i=0; i < winnerBids.length; i++) {
            totalBids += winnerBids[i];
        }
        require (msg.value == totalBids);

        if (SLAContractAddresses.length == winnerBidders.length){
            emit SLAContractsGenerated(msg.sender, now, SLAContractAddresses);
            return SLAContractAddresses;
        }
    }

    function genAuction() 
        public
        payable
        checkState(State.Pending)
        checkTimeBefore(serviceStart)
        checkCustomer(msg.sender)
        returns(address[] memory)
        
    {
        require ( bidders.length > 0);   
        for (uint i=0; i < bidders.length; i++) {
            address newSLAContract = address (new Auction(this, bidders[i], msg.sender, auctionItemStructs[msg.sender].auctionDetails, winnerBids[i]));
            SLAContractPool[newSLAContract].index = SLAContractAddresses.length;
            SLAContractPool[newSLAContract].serviceFee = winnerBids[i];
            SLAContractAddresses.push(newSLAContract);
        }
        uint totalBids;
        for (uint i=0; i < provider.length; i++) {
            totalBids += provider[i];
        }
        require (msg.value == totalBids);

        if (SLAContractAddresses.length == bidders.length){
            emit auctionContractsGenerated(msg.sender, now, SLAContractAddresses);
            return SLAContractAddresses;
        }
    }

    function genWitness() 
        public
        payable
        checkState(State.Pending)
        checkTimeBefore(serviceStart)
        checkCustomer(msg.sender)
        returns(address[] memory)
        
    {
        require ( witnesses.length > 0);   
        for (uint i=0; i < witnesses.length; i++) {
            address newSLAContract = address (new Witness(this, witnesses[i], msg.sender, auctionItemStructs[msg.sender].auctionDetails, winnerBids[i]));
            SLAContractPool[newSLAContract].index = SLAContractAddresses.length;
            SLAContractPool[newSLAContract].serviceFee = winnerBids[i];
            SLAContractAddresses.push(newSLAContract);
        }
        uint totalBids;
        for (uint i=0; i < witnesses.length; i++) {
            totalBids += witnesses[i];
        }
        require (msg.value == totalBids);

        if (SLAContractAddresses.length == witnesses.length){
            emit witnessContractsGenerated(msg.sender, now, SLAContractAddresses);
            return SLAContractAddresses;
        }
    }
}
