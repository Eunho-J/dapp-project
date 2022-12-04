// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import './IRoomShare.sol';

contract RoomShare is IRoomShare{

  mapping(uint256 => Room) private roomMapping;

  mapping(address => Rent[]) private userRentMapping;
  mapping(uint256 => Rent[]) private roomRentMapping;

  uint256 private roomId = 0;
  uint256 private rentId = 0;
  
  function getAllRooms() override external view returns(Room[] memory) {
    Room[] memory allRooms = new Room[](roomId);
    for (uint256 i = 0; i < roomId; i++) {
      allRooms[i] = roomMapping[i];
    }
    return allRooms;
  }

  function getMyRents() override external view returns(Rent[] memory) {
    /* 함수를 호출한 유저의 대여 목록을 가져온다. */
    uint256 length = userRentMapping[msg.sender].length;
    Rent[] memory myRentList = new Rent[](length);
    for(uint256 i = 0; i < length; i++) {
      myRentList[i] = userRentMapping[msg.sender][i];
    }
    return myRentList;
  }

  function getRoomRentHistory(uint _roomId) override external view returns(Rent[] memory) {
    /* 특정 방의 대여 히스토리를 보여준다. */
    uint256 length = roomRentMapping[_roomId].length;
    Rent[] memory rentHistory = new Rent[](length);
    for(uint256 i = 0; i < length; i++) {
      rentHistory[i] = roomRentMapping[_roomId][i];
    }
    return rentHistory;
  }

  function shareRoom( string calldata name, 
                      string calldata location, 
                      uint price ) override external {
    /**
     * 1. isActive 초기값은 true로 활성화, 함수를 호출한 유저가 방의 소유자이며, 365 크기의 boolean 배열을 생성하여 방 객체를 만든다.
     * 2. 방의 id와 방 객체를 매핑한다.
     */
    roomMapping[roomId] = Room(roomId, name, location, true, price * 1e15, msg.sender, new bool[](365));
    emit NewRoom(roomId++);
  }

  function rentRoom(uint _roomId, uint checkInDate, uint checkOutDate) override payable external {
    /**
     * 1. roomId에 해당하는 방을 조회하여 아래와 같은 조건을 만족하는지 체크한다.
     *    a. 현재 활성화(isActive) 되어 있는지
     *    b. 체크인날짜와 체크아웃날짜 사이에 예약된 날이 있는지 
     *    c. 함수를 호출한 유저가 보낸 이더리움 값이 대여한 날에 맞게 지불되었는지(단위는 1 Finney, 10^15 Wei) 
     * 2. 방의 소유자에게 값을 지불하고 (msg.value 사용) createRent를 호출한다.
     */
    Room memory selectedRoom = roomMapping[_roomId];
    require(selectedRoom.isActive, "selected room is not active");
    for (uint256 i = checkInDate; i < checkOutDate; i++) {
      require(!selectedRoom.isRented[i], "selected room has already rented for that day");
    }
    require(msg.value == (checkOutDate - checkInDate) * selectedRoom.price, "received ether does not match");

    _sendFunds(selectedRoom.owner, msg.value);
    _createRent(_roomId, checkInDate, checkOutDate);
  }

  function _createRent(uint256 _roomId, uint256 checkInDate, uint256 checkOutDate) internal {
    /**
     * 1. 함수를 호출한 사용자 계정으로 대여 객체를 만들고, 변수 저장 공간에 유의하며 체크인날짜부터 체크아웃날짜에 해당하는 배열 인덱스를 체크한다(초기값은 false이다.).
     * 2. 계정과 대여 객체들을 매핑한다. (대여 목록)
     * 3. 방 id와 대여 객체들을 매핑한다. (대여 히스토리)
     */
    
    for (uint256 i = checkInDate; i < checkOutDate; i++) {
      roomMapping[_roomId].isRented[i] = true;
    }
    Rent memory newRent = Rent(rentId, _roomId, checkInDate, checkOutDate, msg.sender);
    userRentMapping[msg.sender].push(newRent);
    roomRentMapping[_roomId].push(newRent);
    emit NewRent(_roomId, rentId++);
  }

  function _sendFunds (address owner, uint256 value) internal {
      payable(owner).transfer(value);
  }

  function recommendDate(uint _roomId, uint checkInDate, uint checkOutDate) override external view returns(uint[2] memory) {
    /**
     * 대여가 이미 진행되어 해당 날짜에 대여가 불가능 할 경우, 
     * 기존에 예약된 날짜가 언제부터 언제까지인지 반환한다.
     * checkInDate(체크인하려는 날짜) <= 대여된 체크인 날짜 , 대여된 체크아웃 날짜 < checkOutDate(체크아웃하려는 날짜)
     */
    Room memory selectedRoom = roomMapping[_roomId];
    uint256[2] memory ret;
    for (ret[0] = checkInDate; ret[0] < checkOutDate; ret[0]++) {
      if (selectedRoom.isRented[ret[0]]) break;
    }
    for (ret[1] = checkOutDate - 1; ret[1] >= checkInDate; ret[1]--) {
      if (selectedRoom.isRented[ret[1]]) break;
    }

    require(ret[0] < checkOutDate && ret[1] >= checkInDate, "not rented. check payments");
    return ret;
  }

}