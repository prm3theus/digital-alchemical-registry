pragma solidity ^0.8.0;

library Library {
    struct Signifier {
        string unit;
        bool isComplete;
    }
    struct Resource {
        address creatorAddress; // maybe change this
        string cid;
        string peerId;
        string serviceId;
        uint sizing;
   }
   struct Vote { // begin here, then optimize
       uint status;
       bool isTreeTotem;
       bool isRune;
   }
}

contract TalisRegistry {
    using Library for Library.Signifier;
    uint public MAX_SIZING_ROUND = 100;
    uint public maker;
    uint public arbrFee;

    address public runeAddress;
    address public owner;
    address public treeTotemAddress;

    mapping(string => Library.Signifier) public registry;
    mapping(string => Library.Resource[]) public registryResourceProposals;
    mapping(string => uint) public registryFunds;
    mapping(bytes32 => Library.Vote[]) public votes;

    event ClaimedResource( address indexed claimer, uint indexed status);
    event Vote(address indexed voter, uint indexed status);
    event Test(uint indexed index);

    constructor(uint _maker, uint _arbrFee) {
        owner = msg.sender;
        maker = _maker;
        arbrFee = _arbrFee;
    }

    // TODO: make payable
    function createTalis(string[] memory _resources, uint[] memory _weights, uint _timeframe) payable public {
        
        uint weightCheck = 0;

        // check if weight sum is less than payable 
        for(uint i = 0; i < _weights.length; i++){
            weightCheck += _weights[i];
        }

        require(256 == weightCheck, "Weights must equal a 256 split");

        // check if signifier is already posted
        for(uint i = 0; i < _resources.length; i++){

            if (registry[_resources[i]].isComplete) revert();
            registry[_resources[i]] = Library.Signifier(_resources[i], true);
            
            // record fund distribution
            registryFunds[_resources[i]] = msg.value * _weights[i] / 2**8;
        }
    
    }

    function registerResourceProposal(string memory _resource, string memory _cid, string memory _peerId, string memory _serviceId, uint _sizing) public returns(uint) {
        registryResourceProposals[_resource].push(Library.Resource(msg.sender, _cid, _peerId, _serviceId, _sizing));
        return registryResourceProposals[_resource].length;
    }

    function giveWeightingVote(string memory _resource, uint _proposalId, uint _status) public {
        // check status is 1-4
        require(_status < 5 && _status > 0, "Vote status must be between 1-4");
        votes[keccak256(abi.encodePacked(_resource, _proposalId))].push(Library.Vote(_status, false, false));

        emit Vote(msg.sender, _status);
    }

    function giveTokenVote(string memory _resource, uint _proposalId, uint _tokenId, uint _status, bool _type) public {
        // TODO
        // check if msg.sender owns the _tokenId
        // require(IERC721(runeAddress).ownerOf(_tokenId) == msg.sender, "Token should be owned by the sender");

        // check to see if there was a prior token vote, if not revert
        Library.Vote[] memory proposalVotes = votes[keccak256(abi.encodePacked(_resource, _proposalId))];
        for(uint i = 0;  i < proposalVotes.length; i++) {
            if(_type)
                if(proposalVotes[i].isTreeTotem) revert();
            else
                if(proposalVotes[i].isRune) revert();
        }

        if(_type){
            votes[keccak256(abi.encodePacked(_resource, _proposalId))].push(Library.Vote(_status, true, false)); // true == tree
            // transfer tokenBack to contract
        } else {
            votes[keccak256(abi.encodePacked(_resource, _proposalId))].push(Library.Vote(_status, false, true)); // false == rune
            // transfer tokenBack to contract
        }
    }

    function getVotesOnProposal(string memory _resource, uint _proposalId) public view returns(Library.Vote[] memory) {
        return votes[keccak256(abi.encodePacked(_resource, _proposalId))];
    }

    function getResourceProposals(string memory _resource) public view returns(Library.Resource[] memory) {
        return registryResourceProposals[_resource];
    }

    // requires sybil resistance protection: options -> passport gitcoin, urbitID, worldcoin
    function claimResource(string memory _resource, uint _proposalId, uint _rune) public {

        uint sizing = 0;

        // registryResourceProposals
        for(uint i = 0; i < registryResourceProposals[_resource].length; i++){
            sizing += registryResourceProposals[_resource][i].sizing;
        }

        // time is past a moment, or total sizing of vote is past a certain cid size
        require(sizing > MAX_SIZING_ROUND, "Sizing is not compute-massive enough");

        uint max = 0;
        uint proposalIdMax = 0;
        uint proposalId = 0;

        // iterate through votes and get max and see if aligns with msg.sender
        for(uint i = 0; i < registryResourceProposals[_resource].length; i++){
            if(registryResourceProposals[_resource][i].creatorAddress == msg.sender){
                proposalId = i;
            }
        }

        require(proposalId == _proposalId, "Proposal Id should be owned by msg.sender");

        uint[] memory voteSums = new uint[](registryResourceProposals[_resource].length);
        bool hasTotem = false;
        bool hasRune = false;

        // iterate through votes and get max and see if aligns with msg.sender
        for(uint i = 0; i < registryResourceProposals[_resource].length; i++){

            Library.Vote[] memory proposalVotes = votes[keccak256(abi.encodePacked(_resource, i))];
            uint sum = 0;

            emit Test(proposalVotes.length);

            for(uint j = 0; j < proposalVotes.length; j++){
                sum += proposalVotes[j].status;

                // check if vote is a token vote
                if(proposalVotes[j].isTreeTotem && ! hasRune ){
                    hasTotem = true;
                    require(i == proposalId, "Proposal not equivalent");
                }

                if(proposalVotes[j].isRune){
                    hasRune = true;
                    require(i == proposalId, "Proposal not equivalent");
                }
            }

            voteSums[i] = sum;
        }

        for(uint i = 0;  i < voteSums.length; i++){
            if(max < voteSums[i]){
                max = voteSums[i];
                proposalIdMax = i;
            }
        }

        if (hasRune) {
            emit ClaimedResource(msg.sender, 1);
            // IERC721(runeAddress).transferFrom(this, msg.sender, rune);
        } else if(hasTotem){
            emit ClaimedResource(msg.sender, 2);
            // IERC721(runeAddress).transferFrom(this, msg.sender, rune);
        } else if(proposalIdMax == proposalId) {
            emit ClaimedResource(msg.sender, 3);
            // IERC721(runeAddress).transferFrom(this, msg.sender, rune);
        }
    }

    // function closeVoting() {

    // }
}
