// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract NamingService {

    struct NameData {
        string name;
        address owner;
        uint256 valueLocked;
        uint256 timestamp;
        bool isNameLocked;
    }

    mapping(uint256 => string) private namesRegistered; //stores all the names ever registered
    
    //stores amount in wei an address is able to withdraw because name associated with the address has been unlocked
    mapping(address => uint256) private balanceUnlocked; 
    mapping(bytes32 => address) private hashRegistered;

    mapping(string => NameData) private nameData; 
    uint256 public constant MAX_NAME_LEN = 10;
    uint256 public constant COST_PER_CHAR = 1 ether; 
    uint256 public constant NAME_LOCK_INTERVAL = 1 minutes;
    uint256 public nameCounter = 0;

    //preventing front-running attack - 
    //  First transaction - Send the keccak256 hash of the name user wants to register 
    //  save the hash and address of the sender
    //  Next user sends a second transaction with the name as plain string. registerName function will only
    //  save the name if the keccak hash by the sender was previously registered. 
    //  Miner cannot brute force name from hash to front run, thus front running attac is prevented
    function registerNameHash(bytes32 _hash) public {
        //Currently only the hash of the name is being sent to this function. This can further be improved upon
        // by sending hash(name+msg.sender)
        require(hashRegistered[_hash] == address(0), "Name already registered");
        hashRegistered[_hash] = msg.sender;
    }

    function getAddrAtNameHash(string memory _name) public view returns(address) {
        bytes32 nameHash = keccak256(abi.encodePacked(_name));
        return hashRegistered[nameHash];
    }

    function registerName(string memory _name) public payable {
        bytes32 nameHash = keccak256(abi.encodePacked(_name));
        require(hashRegistered[nameHash] == msg.sender, "Sender is not the registrar of the name hash");
        uint nameLen = bytes(_name).length;
        require(nameLen <= MAX_NAME_LEN, "Name shall be less than 10 characters long");
        require(checkNameAvailable(_name) == true, "Name already registered");
        require(msg.value >= COST_PER_CHAR*nameLen, "Send sufficient funds to register name");
        nameData[_name].owner = msg.sender;
        nameData[_name].name = _name;
        nameData[_name].valueLocked = msg.value;
        nameData[_name].timestamp = block.timestamp;
        nameData[_name].isNameLocked = true;
        nameCounter++;
        namesRegistered[nameCounter] = _name;
    }

    function getNameOwner(string memory _name) public view returns(address) {
        return nameData[_name].owner;
    }

    function getNameData(string memory _name) public returns(string memory, address, uint256, uint256, bool) {
        updateNameLocking(_name);
        return (
            nameData[_name].name,
            nameData[_name].owner,
            nameData[_name].valueLocked,
            nameData[_name].timestamp,
            nameData[_name].isNameLocked
        );
    }



    function getStringLength(string memory _name) public pure returns(uint) {
        //bytes memory name = bytes(_name);
        return bytes(_name).length;
    }
 
    function getCurrentTime() public view returns(uint256) {
        return block.timestamp;
    }

    function getAddedTime(uint256 _addedTime) public view returns(uint256) {
        //keep _addedTime in minutes for this function call
        return block.timestamp + (_addedTime* 1 minutes);
    }

    function checkNameAvailable(string memory _name) public returns(bool) {
        bool isNameAvailable = true;
        if(nameData[_name].owner != address(0)) {
            updateNameLocking(_name);
            if(nameData[_name].isNameLocked == true) {
                isNameAvailable = false;
            }
        }
        return isNameAvailable;
    }

    function updateNameLocking(string memory _name) public {

        if(nameData[_name].owner != address(0)) {
            uint256 timeSinceLocked = block.timestamp - nameData[_name].timestamp;
            if(timeSinceLocked > NAME_LOCK_INTERVAL) {
                nameData[_name].isNameLocked = false;
                uint256 currValueLocked = nameData[_name].valueLocked;
                nameData[_name].valueLocked = 0 wei;
                balanceUnlocked[nameData[_name].owner] += currValueLocked;
                nameData[_name].owner = address(0);
                nameData[_name].timestamp = 0;
                //remove the address from hashRegistered mapping to let someone else register this _name
                bytes32 nameHash = keccak256(abi.encodePacked(_name));
                hashRegistered[nameHash] = address(0);

            }
        }
        
    }

    function getNameAtId(uint256 id) public view returns(string memory) {
        return namesRegistered[id];
    }

    function getBalanceUnlocked(address _address) public view returns(uint256) {
        return balanceUnlocked[_address];
    }

    function getBalanceLocked(string memory _name) public view returns(uint256) {
        return nameData[_name].valueLocked;
    }

    function extendNameLockup(string memory _name) public {
        updateNameLocking(_name);
        require(nameData[_name].owner == msg.sender, "Caller does not own the name to extend lockup period");
        require(nameData[_name].isNameLocked == true, "Name time lock period expired. Cannot extend expired names");
        nameData[_name].timestamp = block.timestamp;
    }

    function withdrawFunds() public {
        require(msg.sender == tx.origin, "contracts not allowed");
        require(balanceUnlocked[msg.sender] > 0, "Caller does not have funds to withdraw");
        uint256 balance = balanceUnlocked[msg.sender];
        balanceUnlocked[msg.sender] = 0 wei;
        payable(msg.sender).transfer(balance);
    }

    

}
