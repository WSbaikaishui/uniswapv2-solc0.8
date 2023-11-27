// SPDX-License-Identifier: UNLICENSED
pragma solidity = 0.8.4;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/IERC20/IERC20.sol";
import  "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract Proposition is Ownable{
    event Deposit(address indexed from, uint256 PropositionID, uint256 amount);
    event AddProposition(address indexed from, uint256 PropositionID, ProposalType proposalType);                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                );
    event Deposit(address indexed from, uint256 amount);
    event WinnerRedeem(address indexed user,uint256 PropositionID, uint256 amount);

    IERC20 public USDTContract;
    uint256 JobID;
    enum TokenStatus {Pending, Active, Completed, Cancelled}
    enum ProposalType {Normal, Price,Oracle}
    

    
    struct  Proposal {
        uint256 PropositionID;
        string Name;
        string Description;
        address TokenIDYes;
        address TokenIDNo;
        uint256 Deadline;
        TokenStatus Status;
        address JudgeID;
        ProposalType proposalType;
        PriceProposal priceProposal;
        OracleProposal oracleProposal; 
        address Creator;
    }


    struct PriceProposal{
        AggregatorV3Interface  coinPriceFeed;
        uint256 Aim;
        bool isBig;
    }

    struct OracleProposal{
        string OracleUrl;
        string filter;
        string value;
    }
    Proposal[] public proposals;



    constructor(address _USDT, uint256 _jobID){
        USDTContract = IERC20(_USDT);
        JobID = _jobID;
    }
    modifier ProposalExists(uint256 _proposalID) {
        require(proposals[_proposalID/3].TokenIDYes != address(0), "Proposal does not exist");
        _;
    }

    function addOracleProposal(string memory _Name, string memory _Description,uint256 _Deadline, string _oracleUrl, string _filter, string _value) public  {
        //TODO  设置yes和no token
        ERC20 token1  = new ERC20(proposals.length*3 + 1, symbol1);
        ERC20 token2  = new ERC20(proposals.length*3 + 2, symbol1);
        NormalProposal memory normalProp = OracleProposal({
                oracleUrl: _oracleUrl,
                filter: _filter,
                value: _value
            });
         proposals.push(Proposal(
            proposals.length*3,
            _Name, 
            _Description, 
            token1,
            token2,
            _Deadline, 
            TokenStatus.Pending,  
            address(0), 
            ProposalType.Normal,
            PriceProposal(AggregatorV3Interface(address(0)), 0, false),
            normalProp,
            msg.sender
            ));

        emit AddProposition(msg.sender, proposals.length*3, ProposalType.Oracle)
    }
     
    function addPriceProposal(string memory _Name, string memory _Description,uint256 _Deadline, address _priceFeed, uint256 _aim, bool _isBig) public {
        //TODO  设置yes和no token
        ERC20 token1  = new ERC20(proposals.length*3 + 1, symbol1);
        ERC20 token2  = new ERC20(proposals.length*3 + 2, symbol1);
        PriceProposal memory priceProp = PriceProposal({
                coinPriceFeed: AggregatorV3Interface(_priceFeed),
                aim: _aim,
                isBig: _isBig
            });
        proposals.push(Proposal(
            proposals.length*3,
            _Name, 
            _Description, 
            token1,
            token2,
            _Deadline, 
            TokenStatus.Pending,  
            ProposalType.Price,
            OracleProposal("", 0, false),
            priceProp,
     msg.sender
            ));

        emit AddProposition(msg.sender, proposals.length*3, ProposalType.Price);
    }

    function addNormalProposal(string memory _Name, string memory _Description,uint256 _Deadline, string _url) public  {
     //TODO  设置yes和no token
        ERC20 token1  = new ERC20(proposals.length*3 + 1, symbol1);
        ERC20 token2  = new ERC20(proposals.length*3 + 2, symbol1);
  proposals.push(Proposal(
            proposals.length*3,
            _Name, 
            _Description, 
            token1,
            token2,
            _Deadline, 
            TokenStatus.Pending,  
            ProposalType.Price,
            OracleProposal(_url, 0, false),
            PriceProposal(address(0), 0, false),
            msg.sender
            ));
     emit AddProposition(msg.sender, proposals.length*3, ProposalType.Normal);
    }


    function deposit(uint256 _ProposalID, uint256 _Amount) external ProposalExists(_ProposalID){
        require(amount > 0, "Amount must be greater than 0");
        require(proposals[_ProposalID/3].Deadline > block.timestamp, "Proposal is expired");
        // 使用 ERC-20 代币合约的 transferFrom 函数将代币从用户地址转移到合约地址
        bool success = USDTContract.transferFrom(msg.sender, address(this), amount);
        require(success, "Token transfer failed");
        IERC20 token1 = IERC20(proposals[_ProposalID/3].Token1);
        IERC20 token2 = IERC20(proposals[_ProposalID/3].Token2);
        token1.mint(msg.sender, _Amount);
        token2.mint(msg.sender, _Amount);

        emit Deposit(msg.sender, _ProposalID, _Amount);
    }

    function Redeem(uint256 _ProposalID, uint256 _Amount) external unjudgedProposalExists(_ProposalID){
        require(amount > 0, "Amount must be greater than 0");
        require(proposals[_ProposalID/3].Status == TokenStatus.Active, "Proposal is not active");
        require(proposals[_ProposalID/3].Deadline > block.timestamp, "Proposal is expired");
     
        IERC20 token1 = IERC20(proposals[_ProposalID/3].Token1);
        IERC20 token2 = IERC20(proposals[_ProposalID/3].Token2);
        require(token1.balanceOf(msg.sender) >= _Amount, "Insufficient balance");
        require(token2.balanceOf(msg.sender) >= _Amount, "Insufficient balance");
        token1.burn( _Amount );
        token2.burn(msg.sender, _Amount);
        bool success = USDTContract.transferFrom(address(this), msg.sender, amount);
        require(success, "Token transfer failed");

        emit Redeem(msg.sender, _ProposalID, _Amount);
    }


    function WinnerRedeem(uint256 _ProposalID) external ProposalExists(_ProposalID){

        require(judgedProposals[_ProposalID].Status == TokenStatus.Completed, "Proposal is not judged");

        IERC20 winnerToken = IERC20(proposals[_ProposalID].JudgeID);
        uint256 balance = winnerToken.balanceOf(msg.sender);
        winnerToken.burn(balance);

        bool success = USDTContract.transferFrom(address(this),msg.sender, balance);
        require(success, "Token transfer failed");

        emit WinnerRedeem(msg.sender, _ProposalID, balance);
    }




    function getProposal(uint256 _ProposalID) public view returns (Proposal memory) {
        return proposals[_ProposalID/3];
    }

    function getProposals() public view returns (Proposal[] memory) {
        return proposals;
    }

    function getProposalsByStatus(TokenStatus _Status) public view returns (Proposal[] memory) {
        Proposal[] memory proposalStatus = new Proposal[](proposals.length);
        for (uint256 i = 0; i < proposals.length; i++) {
            if (proposals[i].Status == _Status) {
                proposalStatus[i] = proposals[i];
            }
        }
        return proposalStatus;
    }

    function judgeNormalProposalByID(uint256 _ProposalID, address _judgeID)  external proposalExists(_ProposalID) {
        require(proposals[_ProposalID/3].Creator == msg.sender, "Only creator can judge");
        require(proposals[_ProposalID/3].Deadline < block.timestamp, "Proposal is not expired");
        require(proposals[_ProposalID/3].TokenIDYes == _judgeID || proposals[_ProposalID/3].TokenIDNo == _judgeID, "Only yes or no token can judge");
        
        
        proposals[_ProposalID/3].JudgeID = _JudgeID;
        proposals[_ProposalID/3].Status = TokenStatus.Completed;
        emit JudgeNormalProposalByID(_ProposalID, _judgeID);
    }
    



    function judgePriceProposalByID(uint256 _ProposalID)  external proposalExists(_ProposalID) {
        require(proposals[_ProposalID/3].Deadline < block.timestamp, "Proposal is not expired");
        (, int256 price,,,) = proposals[_ProposalID/3].priceProposal.coinPriceFeed.latestRoundData();
        
        if proposals[_ProposalID/3].priceProposal.isBig {
            if price >= proposals[_ProposalID/3].priceProposal.price {
                proposals[_ProposalID/3].JudgeID = proposals[_ProposalID/3].TokenIDYes;
               
            }else{
                proposals[_ProposalID/3].JudgeID = proposals[_ProposalID/3].TokenIDNo;
            }
        }else{
             if price <= proposals[_ProposalID/3].priceProposal.price {
                proposals[_ProposalID/3].JudgeID = proposals[_ProposalID/3].TokenIDYes;
            }else{
                proposals[_ProposalID/3].JudgeID = proposals[_ProposalID/3].TokenIDNo;
            }
        }
       
        proposals[_ProposalID/3].Status = TokenStatus.Completed;
        emit JudgePriceProposalByID(_ProposalID, _judgeID);
    }
    function getJudgeID(uint256 _ProposalID) public view returns (uint256) {
        return proposals[_ProposalID/3].JudgeID;
    }

}

//  function getHistoricalPrice(address _proxyAddress, uint _unixTime) public returns (bytes32
// requestId)
//     {

//         Chainlink.Request memory request = buildChainlinkRequest(JobID, address(this), 
// this.singleResponseFulfill.selector);

//         // Set the URL to perform the GET request on
//         request.add("proxyAddress", addressToString(_proxyAddress));
//         request.add("unixDateTime", uint2str(_unixTime));

//         //set the timestamp being searched, we will use it for verification after
//         searchTimestamp = _unixTime;

//         // Sends the request
//         return sendChainlinkRequestTo(oracle, request, fee);
//     }