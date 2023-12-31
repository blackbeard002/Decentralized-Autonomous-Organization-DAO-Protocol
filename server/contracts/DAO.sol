//SPDX-License-Identifier:MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DAO is ERC20
{
    /*info-----------------------------------------------------------

    cost of 1 vote=50 DAO
    1 ether=100 DAO tokens

    info------------------------------------------------------------*/



    //CUSTOM DATA TYPES-------------------------------------------BEGINS
    enum VotingStatus
    {
        notStarted, 
        inProgress,
        completed
    }

    struct Proposals
    {
        string proposal; 
        string[] options;
        address proposer;
        uint threshold;
        VotingStatus votingStatus;
        uint highestValue;
        uint[] results;
        uint winningOption;
        bool result;
    }
    //CUSTOM DATA TYPES-----------------------------------------------ENDS



    //STATE VARIABLES------------------------------------------------------BEGINS
    address payable public manager;

    uint public pollId;

    //pollId=>Proposals
    //contains all the info about the proposals
    mapping(uint=>Proposals) public proposals;

    //[users][pollId]=votes cast 
    //stores how many votes were cast by a user for any particular poll 
    mapping(address=>mapping(uint=>uint)) public votesCast;

    //stores how much a user has staked
    mapping(address=>uint) public stakedAmount;

    //stores the time duraion when it was staked at
    mapping(address=>uint) public stakedAt;

    //delegator=>validator=>true if delegated
    mapping(address=>mapping(address=>bool)) delegates;
    //STATE VARIABLES-------------------------------------------------------ENDS



    //EVENTS---------------------------------------------------------------BEGINS
    event newProposalDetails
    (
        uint pollId,
        string proposal, 
        address proposer
    );

    event thresholdSet
    (
        uint pollId,
        uint threshold
    );

    event tokensPurchased
    (
        uint tokensPurchased 
    );
    //EVENTS---------------------------------------------------------------ENDS


    //MODIFIERS-----------------------------------------------------------BEGINS
    modifier onlyManager
    {
        require(msg.sender==manager,"Only the manager can call");
        _;
    }
    //MODIFIERS-----------------------------------------------------------ENDS

    constructor() ERC20("DecentralizedAutonomousOrganization","DAO")
    {
        manager=payable(msg.sender); 
    } 
    
    //ADD NEW PROPOSALS()-----------------------------------------------------------------------BEGINS
    function newProposal(string memory proposal,string[] memory options) public returns(uint)
    {
        require(balanceOf(msg.sender)>=25,"insufficient DAO");
        //costs 25 DAO tokens to add a poll
        _transfer(msg.sender, manager, 25);
        pollId++;
        proposals[pollId]=Proposals
        ({
            proposal:proposal,
            options:options,
            proposer:msg.sender,
            threshold:0,
            votingStatus:VotingStatus.notStarted,
            highestValue:0,
            results:new uint[](options.length),
            winningOption:0,
            result:false
        });
        emit newProposalDetails
        (
            pollId,
            proposal,
            msg.sender
        );
        return pollId;
    }

    //Set the threshold to win 
    function setThreshold(uint _pollId,uint threshold) public onlyManager 
    {
        proposals[_pollId].threshold=threshold; 
        emit thresholdSet
        (
            _pollId,
             threshold
        );
    }
    //ADD NEW PROPOSALS()-----------------------------------------------------------------ENDS



    //PURCHASE DAO TOKENS()--------------------------------------------------------------BEGINS
    
    //tokens should be bought in multiples of 100 for simplicity 
    function purchaseDAOtokens() public payable 
    {
        uint tokens;
        tokens=(msg.value/1 ether)*100;
        _mint(msg.sender, tokens);
        emit tokensPurchased
        (
            tokens
        );
    }
    //PURCHASE DAO TOKENS()---------------------------------------------------------------ENDS


    //VOTING----------------------------------------------------------------------------------------------------------BEGINS
    function changeVotingState(VotingStatus status,uint _pollId) public onlyManager
    {
        proposals[_pollId].votingStatus=status;
        if((status==VotingStatus.completed)&&(proposals[_pollId].highestValue>proposals[_pollId].threshold))
        {
            proposals[_pollId].result=true;
        }

    }

    function vote(uint _pollId,uint option) public 
    {
        require(_pollId<=pollId && _pollId>0,"invalid poll ID");
        uint amount=checkVoteCost(_pollId);
        require(msg.sender!=proposals[_pollId].proposer,"you can't vote on your own poll");
        require(proposals[_pollId].threshold>0,"Threshold isn't set yet");
        require(proposals[_pollId].votingStatus==VotingStatus.inProgress,"Voting isn't in progress");
        require(balanceOf(msg.sender)>=amount,"insufficient DAO");
        votesCast[msg.sender][_pollId]++;
        proposals[_pollId].results[option]++;
        if(proposals[_pollId].results[option]>proposals[_pollId].highestValue)
        {
            proposals[_pollId].highestValue=proposals[_pollId].results[option];
            proposals[_pollId].winningOption=option;
        }
        _transfer(msg.sender, manager, amount);
    }

    //function for the delegator to vote
    function delegateVote(uint _pollId,uint option,address delegator) public
    {
        require(delegates[delegator][msg.sender]==true,"you aren't a delegator");
        require(_pollId<=pollId && _pollId>0,"invalid poll ID");
        uint amount=checkVoteCost(_pollId);
        require(msg.sender!=proposals[_pollId].proposer && delegator!=proposals[_pollId].proposer,"you can't vote on your own poll");
        require(proposals[_pollId].threshold>0,"Threshold isn't set yet");
        require(proposals[_pollId].votingStatus==VotingStatus.inProgress,"Voting isn't in progress");
        require(balanceOf(delegator)>=amount,"insufficient DAO");~
        votesCast[delegator][_pollId]++;
        proposals[_pollId].results[option]++;
        if(proposals[_pollId].results[option]>proposals[_pollId].highestValue)
        {
            proposals[_pollId].highestValue=proposals[_pollId].results[option];
            proposals[_pollId].winningOption=option;
        }
        _transfer(delegator, manager, amount);
    }
    //VOTING---------------------------------------------------------------------------------------------------------------ENDS


    //TRANSFERS TO MANAGER---------------------------------BEGINS
    function transferEthToManager() public onlyManager
    {
        manager.transfer(address(this).balance);
    }
    //TRANSFERS TO MANAGER---------------------------------ENDS


    //DELEGATION--------------------------------------------------------BEGINS
    function delegation(address delegate) public 
    {
        delegates[msg.sender][delegate]=true;
    }
    //DELEGATION---------------------------------------------------------ENDS


    //STAKING-----------------------------------------------------------------BEGINS
    function stake(uint amount) public 
    {
        require(balanceOf(msg.sender)>=amount,"insufficient DAO");
        if(stakedAmount[msg.sender]>0)
        {
            claim();
        }
        _transfer(msg.sender, manager, amount);
        stakedAmount[msg.sender]+=amount; 
        stakedAt[msg.sender]=block.timestamp;
    }

    function claim() public
    {
        require(stakedAmount[msg.sender]>0,"no tokens staked.nothing to claim");
        uint currentBlockTimeStamp=block.timestamp;
        uint rewards;
        rewards=((currentBlockTimeStamp-stakedAt[msg.sender])/60)+((stakedAmount[msg.sender])/50);
        _mint(msg.sender, rewards);
        stakedAt[msg.sender]=currentBlockTimeStamp;
    }

    function unStake(uint amount) public 
    {
        require(stakedAmount[msg.sender]>=amount,"less tokens are staked");
        if(block.timestamp>stakedAt[msg.sender]+60)
        {
            claim();
        }
        
        stakedAmount[msg.sender]-=amount;
        _transfer(manager, msg.sender, amount);
    }
    //STAKING----------------------------------------------------------------ENDS

    
    //CHECK VALUES-----------------------------------------------------------------BEGINS
    function checkDAOtokenBalance() public view returns(uint)
    {
        return balanceOf(msg.sender);
    }

    function checkVoteCost(uint _pollId) public view returns(uint)
    {
        return (((votesCast[msg.sender][_pollId])+1)**2)*50;
    }

    function checkProposalDetails(uint _pollId) public view returns(string memory,string[] memory)
    {
        return (proposals[_pollId].proposal,proposals[_pollId].options);
    }

    function checkVotingStatus(uint _pollId) public view returns(VotingStatus)
    {
        return proposals[_pollId].votingStatus;
    }

    function checkLiveVoteCount(uint _pollId) public view returns(uint,string memory)
    {
        require(proposals[_pollId].votingStatus==VotingStatus.inProgress,"voting isn't in progress");
        return (proposals[_pollId].highestValue,proposals[_pollId].options[proposals[_pollId].winningOption]);
    }

    function checkFinalResult(uint _pollId) public view returns(string memory)
    {
        require(proposals[_pollId].votingStatus==VotingStatus.completed,"voting hasn't completed yet");
        return proposals[_pollId].options[proposals[_pollId].winningOption];
    }

    function checkPollResult(uint _pollId) public view returns(bool)
    {
        require(proposals[_pollId].votingStatus==VotingStatus.completed,"voting hasn't completed yet");
        return proposals[_pollId].result;
    }

    function checkManagerEthBalance() public view onlyManager returns(uint) 
    {
        return manager.balance; 
    }

    //tokens should be bought in multiples of 100 for simplicity 
    function checkTokensCostInEther(uint tokens) public pure returns(uint)
    {
        //tokens/tokensPerEther
        return tokens/100; 
    }

    function checkDelegatorsBalance(address delegator) public view returns(uint) 
    {
        require(delegates[delegator][msg.sender]==true,"you aren't a delegator");
        return balanceOf(delegator);
    }

    //CHECK VALUES-------------------------------------------------------------------------------------------ENDS
}