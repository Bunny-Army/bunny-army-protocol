// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IJswapRouter.sol";

contract BunnyContributor is Ownable {
    
    address public constant USDT = 0x382bB369d343125BfB2117af9c149795C6C65C50;
    address public constant JF   = 0x5fAc926Bf1e638944BB16fb5B787B5bA4BC85b0A;
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

    IERC20 public bunny;
    address public jfRouter;
    uint256 public totalPoint;

    uint256 public destoryRate = 70;

    bool public frozen;

    address[] public contributors;
    mapping(address => uint256) public userIndex; // 1-based
    mapping(address => uint256) public userPoint; 

    event CliamEven(uint256 _amount);

    constructor(address _token, address _jfRouter) {
        bunny  = IERC20(_token);
        frozen = false;
        jfRouter = _jfRouter;

        bunny.approve(_jfRouter, ~uint256(0));
    }

    function setContributor(address _user, uint256 _point) external onlyOwner() {
        require(frozen, 'BunnyContributor: Contract not frozen.');

        if(userIndex[_user] == 0) { //new
            require(_point > 0, 'BunnyContributor: Cannot add 0 weight');
            contributors.push(_user);
            userIndex[_user] = contributors.length;
            userPoint[_user] = _point;
            totalPoint += _point;
        } else { //modify
            totalPoint = totalPoint + _point - userPoint[_user];
            userPoint[_user] = _point; //update
        }
    }

    function claim() external {
        require(!frozen, 'BunnyContributor: Contract is frozen.');
        uint256 _len = contributors.length;
        require(_len > 0, 'BunnyContributor: Contributors is empty');

        uint256 balance = bunny.balanceOf(address(this));

        uint256 destoryShare = balance * destoryRate / 100;
        uint256 devShare = balance - destoryShare;

        destoryJf(destoryShare);

        uint256 _totalPoint = totalPoint; // gas saving
        require(devShare >= _totalPoint , 'BunnyContributor: Balance too small');
        for(uint256 i = 0; i < _len; i++) {
            address _user = contributors[i];
            uint256 _point = userPoint[_user];
            if(_point > 0) {
                safeTransfer(address(bunny), _user,  devShare * _point / _totalPoint);
            }
        }       
        emit CliamEven(balance);
    }

    function destoryJf(uint256 bunnyAmount) private {

        address[] memory path = new address[](2);
        path[0] = address(bunny);
        path[1] = USDT;
        path[2] = JF;
        IJswapRouter(jfRouter).swapExactTokensForTokens(
                bunnyAmount,
                0,
                path,
                DEAD,
                block.timestamp
        );
    }

    function exit(address _token) external onlyOwner() {
        address to = owner();
        safeTransfer(_token, to, IERC20(_token).balanceOf(address(this)));
        safeTransferNative(to, address(this).balance);
    }

    function freeze() public onlyOwner {
        frozen = true;
    }

    function unfreeze() public onlyOwner {
        frozen = false;
    }

    function safeTransferNative(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'MasterTransfer: ETH_TRANSFER_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'MasterTransfer: TRANSFER_FAILED');
    }

    receive() external payable {
    }
}