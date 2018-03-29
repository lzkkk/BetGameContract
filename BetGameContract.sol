pragma solidity ^0.4.21;
pragma experimental ABIEncoderV2;

/**
 * SafeMath
 */
library SafeMath {
  function mul(uint256 a, uint256 b) internal constant returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal constant returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal constant returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

contract Ownable {
  address public owner;
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  function Ownable() {
    owner = msg.sender;
  }
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  function transferOwnership(address newOwner) onlyOwner public {
    require(newOwner != address(0));
    OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}

// 竞猜
contract GuessingGame is Ownable{
   using SafeMath for uint256;
   
   //event 
   event betEvent(address _betAddress, uint _betNum, uint _betValue, bytes _betData, uint timestamp);
   event betBeginEvent(uint _blockNum);
   event betEndEvent(uint _blockNum);
   event drawEvent(uint _blockNum, uint _drawNum);
   event distributeEvent(uint _blockNum, address _betAddress, uint _betGet);
   
   struct DrawHistory{
       uint drawNum;
       uint blockNum;
       uint totalBet;
   }
   
   //struct define
   struct BetInfo{
       address betAddress;
       uint betValue;
       uint bbnum;
   }
   
   struct GuessingGameInfo{
       uint gameBegin;
       uint gameEnd;
       uint betBegin;
       uint betEnd;
       uint drawBlock;
       uint distributeBlock;

       uint drawNum;
       uint totalBet;
       
       BetInfo[] betInfos;  
       mapping(uint => uint) betPoolInfo;
   }
   
   DrawHistory[] drawHistory;   //
   GuessingGameInfo[] gameHistory;
   GuessingGameInfo public lastGameInfo;      // last gameinfo 
   GuessingGameInfo public currentGameInfo;   // current gameinfo 
   
   //BetInfo[] public betInfos; 
   
   uint public fee;
   address public feeAddress;
   uint public betInterval;
   uint public drawInterval;
   uint public distributeInterval;
   bool public enable;
   uint public gameStatus;  // 0: game begin 1:betting begin 2:betting end 3:drawing/distribute beging 4:game end

   function GuessingGame(){
       
        betInterval = 1000;
        drawInterval = 10;
        distributeInterval = 0;
        enable = true;
        fee = 100;  // 1%
        feeAddress = msg.sender;
        
        currentGameInfo.gameBegin = block.number;
        currentGameInfo.betBegin = currentGameInfo.gameBegin + 1;
        currentGameInfo.betEnd = currentGameInfo.betBegin + betInterval;
        currentGameInfo.drawBlock = currentGameInfo.betEnd + drawInterval;

        currentGameInfo.totalBet += this.balance;
        
        gameStatus = 0;
   } 
   
   function DestroyGame(address _newContract) onlyOwner{
       
       require(_newContract != address(0));
       selfdestruct(_newContract);
       
   }
   
   function initNextGame() public {
        
        lastGameInfo = currentGameInfo;
        if (gameHistory.length > 100) {
           delete gameHistory[0];
        }
        gameHistory.push(currentGameInfo);
        delete currentGameInfo;
        clearBetInfo();
        currentGameInfo.gameBegin = block.number;
        currentGameInfo.betBegin = currentGameInfo.gameBegin + 1;
        currentGameInfo.betEnd = currentGameInfo.betBegin + betInterval;
        currentGameInfo.drawBlock = currentGameInfo.betEnd + drawInterval;
        currentGameInfo.totalBet += this.balance;
        gameStatus = 0;
        
   }
   
   function setGamePama(uint _betInterval, uint _drawInterval, uint _distributeInterval, bool _enable) onlyOwner{
       require(block.number > currentGameInfo.gameEnd && _betInterval >= 0 && _drawInterval >= 0 && _distributeInterval >= 0);
       betInterval = _betInterval;
       drawInterval = _drawInterval;
       distributeInterval = _distributeInterval;
       enable = _enable;
   }
   
   function setFee(uint _fee, address _feeAddress) onlyOwner{
       require(_feeAddress != address(0) && _fee >= 0 && _fee < fee);
       feeAddress = _feeAddress;
       fee = _fee;
   }
   
   function random(uint offSet) internal constant returns (uint){
       require(offSet >= 0);
       bytes32 blockhash = block.blockhash(lastGameInfo.drawBlock - offSet);
       uint random = uint(blockhash) + block.timestamp;
       return random;    
   } 
   
   //touzhu
   function () payable{

      address betAddress = msg.sender;
      uint betValue = msg.value;
      uint num = bytesToUint(msg.data);
       
      betEvent(betAddress, num, betValue, msg.data, block.timestamp);
       
      require(betAddress != address(0) && betValue > 0 && betNumValid(num) && canBet());

      currentGameInfo.betInfos.push(BetInfo(betAddress, betValue, num));
      currentGameInfo.betPoolInfo[num] += betValue;
      currentGameInfo.totalBet += betValue;
      
   }
   
   function drawing() onlyOwner{
    
       //require(block.number >= currentGameInfo.drawBlock);

       uint randomNum = random(0);
       uint offSet = randomNum % 200 + 1;
       randomNum = random(offSet);
       uint randomDrawNum = randomNum % 7 + 1;
       
       currentGameInfo.drawNum = randomDrawNum;
       
       DrawHistory memory history = DrawHistory(currentGameInfo.drawNum, currentGameInfo.drawBlock, currentGameInfo.totalBet);
       drawHistory.push(history);

       drawEvent(randomDrawNum, block.number);
       
       uint betNumPool = currentGameInfo.betPoolInfo[randomDrawNum];
        if(betNumPool > 0){
            for(uint i = 0; i < currentGameInfo.betInfos.length; ++i){
                BetInfo info = currentGameInfo.betInfos[i];
                if(info.bbnum == randomDrawNum){
                    uint betGet = currentGameInfo.totalBet * info.betValue / betNumPool;
                    uint betFee = betGet * fee / 10000;
                    betGet -= betFee;
                    info.betAddress.transfer(betGet);
                    feeAddress.transfer(betFee);
                    distributeEvent(block.number, info.betAddress, betGet);
                    currentGameInfo.totalBet = currentGameInfo.totalBet - betGet - betFee;
                }
            }
        }
       
       gameStatus = 3;
       currentGameInfo.distributeBlock = block.number;
       currentGameInfo.gameEnd = currentGameInfo.distributeBlock + 10;
   }
   
   function getDrawHistory() public constant returns (uint[], uint[], uint[]){
       
       uint256 length = drawHistory.length;
       uint[] memory drawNum = new uint[](length);
       uint[] memory blockNum = new uint[](length);
       uint[] memory totalBet = new uint[](length);
       for(uint i = 0; i < drawHistory.length; ++i){
           drawNum[i] = drawHistory[i].drawNum;
           blockNum[i] = drawHistory[i].blockNum;
           totalBet[i] = drawHistory[i].totalBet;
       }
       return (drawNum, blockNum, totalBet);
       
   }
  
   
   function getBetHistoryByAddress(address _betAddress) public constant returns(uint[8][]){
       
       uint[8][] memory addressBetInfos = new uint[8][](101);
       uint k = 0;
       for (uint i = 0; i < gameHistory.length; i ++) {
           GuessingGameInfo game = gameHistory[i];
           bool hasRecord =  false;
           for (uint j = 0; j < game.betInfos.length; j ++) {
               BetInfo info = game.betInfos[j];
               uint drawBlock = game.drawBlock;
               if (info.betAddress == _betAddress) {
                   addressBetInfos[k][info.bbnum] += info.betValue;
                   hasRecord = true;
               }
           }
           if (hasRecord) {
                k ++;
                addressBetInfos[k][0] = drawBlock;
            }
       }
       
       hasRecord = false;
       for (i = 0; i < currentGameInfo.betInfos.length; i ++) {
           info = currentGameInfo.betInfos[i];
           if (info.betAddress == _betAddress) {
                addressBetInfos[k][info.bbnum] += info.betValue;
                hasRecord = true;
            }
       }
       if (hasRecord) {
            k ++;
            addressBetInfos[k][0] = drawBlock;
        }
        
       return addressBetInfos;
       
   }
   
   function getGameBetInfo() public constant returns(uint[]) {
        uint256 length = 7;
        uint256[] memory betInfo = new uint256[](length);
        for (uint i = 0; i < length; i++) {
               betInfo[i] = currentGameInfo.betPoolInfo[i+1];
        }
        return betInfo;
   }
   
   //
   function canBet() internal constant returns(bool){
       if(enable && block.number >= currentGameInfo.betBegin && block.number <= currentGameInfo.betEnd){
           return true;
       }
       return false;
   }
   
   function betNumValid(uint betNum) internal constant returns(bool){
       if(betNum >= 1 && betNum <=7) return true;
       return false;
   }
   
    function bytesToUint(bytes _bytes) internal constant returns (uint){
        uint b = uint(_bytes[3]);
        return b;
    }
    
    function clearBetInfo() internal constant {
        for (uint i = 0; i < 7; i++) {
            currentGameInfo.betPoolInfo[i+1] = 0;
        }
    }
}
