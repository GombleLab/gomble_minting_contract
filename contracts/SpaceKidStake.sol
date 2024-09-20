// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./interfaces/ISpaceKid.sol";

contract SpaceKidStake is OwnableUpgradeable, ReentrancyGuardUpgradeable, IERC721Receiver {
    using EnumerableSet for EnumerableSet.UintSet;

    ISpaceKid public spaceKid;
    uint256 public unlockTime;

    struct StakingStatus {
        uint256 lastPoint;
        uint256 lastStakedTokenCount;
        uint256 timestamp;
    }

    struct Multiplier {
        uint256 from;
        uint256 to;
        uint256 multiplier;
    }

    mapping(address => StakingStatus) private _stakingStatus;
    mapping(address => EnumerableSet.UintSet) private _stakedTokens;
    Multiplier[] private _multipliers;

    uint256 public constant BOOST_MANTISSA = 10 ** 2;

    event UpdateMultiplier(uint256 index, uint256 from, uint256 to, uint256 multiplier);
    event Stake(address owner, uint256[] tokenIds, uint256 lastPoint, uint256 lastStakedTokenCount, uint256 timestamp);
    event Claim(address owner, uint256[] tokenIds);
    event SetUnlockTime(uint256 unlockTime);
    event SetMultiplier(Multiplier[] multipliers);

    function initialize(address owner, address _spaceKid, uint256 _unlockTime) external initializer {
        __Ownable_init(owner);
        __ReentrancyGuard_init();
        spaceKid = ISpaceKid(_spaceKid);
        _setUnlockTime(_unlockTime);
    }

    function setUnlockTime(uint256 _unlockTime) external onlyOwner {
        _setUnlockTime(_unlockTime);
    }

    function setMultiplier(Multiplier[] memory multipliers) external onlyOwner {
        require(multipliers.length > 0, "INVALID MULTIPLIER SIZE");
        delete _multipliers;

        for (uint256 index = 0; index < multipliers.length; index++) {
            Multiplier memory currentMultiplier = multipliers[index];

            require(currentMultiplier.from < currentMultiplier.to, "INVALID MULTIPLIER RANGE");
            require(currentMultiplier.multiplier > 0, "INVALID MULTIPLIER");
            if (index > 0) {
                Multiplier memory previousMultiplier = multipliers[index - 1];
                require(previousMultiplier.to == currentMultiplier.from, "MISMATCHED MULTIPLIER RANGE");
            }

            _multipliers.push(currentMultiplier);
        }
        emit SetMultiplier(multipliers);
    }

    function stake(uint256[] memory tokenIds) external {
        if (unlockTime != 0) {
            require(unlockTime > block.timestamp, "CANNOT STAKE");
        }
        require(unlockTime != 0 && unlockTime > block.timestamp, "CANNOT STAKE");
        require(tokenIds.length > 0, "INVALID SIZE");
        address owner = msg.sender;
        require(spaceKid.isApprovedForAll(owner, address(this)), 'NEED APPROVAL');
        EnumerableSet.UintSet storage stakedTokens = _stakedTokens[owner];

        for (uint256 index = 0; index < tokenIds.length; index++) {
            uint256 tokenId = tokenIds[index];
            require(spaceKid.ownerOf(tokenId) == owner, 'ONLY OWNER CAN STAKE');
            assert(stakedTokens.add(tokenId));
            spaceKid.safeTransferFrom(owner, address(this), tokenId);
        }

        StakingStatus storage stakingStatus = _stakingStatus[owner];
        stakingStatus.lastPoint = getStakingPoint(owner, block.timestamp);
        stakingStatus.timestamp = block.timestamp;
        stakingStatus.lastStakedTokenCount = stakedTokens.length();
        _stakingStatus[owner] = stakingStatus;

        emit Stake(owner, tokenIds, stakingStatus.lastPoint, stakingStatus.lastStakedTokenCount, stakingStatus.timestamp);
    }

    function claim(uint256[] memory tokenIds) external {
        require(unlockTime != 0 && unlockTime <= block.timestamp, "CANNOT CLAIM");
        require(tokenIds.length > 0, "INVALID SIZE");
        address owner = msg.sender;

        for (uint256 index = 0; index < tokenIds.length; index++) {
            uint256 tokenId = tokenIds[index];
            require(_stakedTokens[owner].contains(tokenId), 'INVALID TOKEN');
            assert(_stakedTokens[owner].remove(tokenId));
            spaceKid.safeTransferFrom(address(this), owner, tokenId);
        }

        emit Claim(owner, tokenIds);
    }

    function getMultipliers() external view returns (Multiplier[] memory) {
        return _multipliers;
    }

    function getStakingStatus(address user) external view returns (StakingStatus memory) {
        return _stakingStatus[user];
    }

    function getStakedTokens(address user) external view returns (uint256[] memory) {
        return _stakedTokens[user].values();
    }

    function getStakingPoint(address user, uint256 _calculateTo) public view returns (uint256) {
        StakingStatus memory stakingStatus = _stakingStatus[user];
        uint256 snapshotTime = stakingStatus.timestamp;
        if (snapshotTime == 0) {
            return 0;
        }
        require(_calculateTo >= snapshotTime, "INVALID CALCULATE TO");

        uint256 boost = _getBoost(stakingStatus.lastStakedTokenCount);
        uint256 calculateTo = _calculateTo;
        if (unlockTime != 0 && unlockTime < calculateTo) {
            calculateTo = unlockTime;
        }
        uint256 cumulativePoint = 0;
        for(uint256 index = 0; index < _multipliers.length; index++) {
            Multiplier memory multiplier = _multipliers[index];
            if (multiplier.to <= snapshotTime) {
                continue;
            }

            if (multiplier.from >= calculateTo) {
                break;
            }

            uint256 start = snapshotTime > multiplier.from ? snapshotTime : multiplier.from;
            uint256 end = calculateTo < multiplier.to ? calculateTo : multiplier.to;

            if (start >= end) {
                continue;
            }

            uint256 elapsed = end - start;
            cumulativePoint += _calculateStakingPoint(elapsed, multiplier.multiplier, boost);
        }
        return stakingStatus.lastPoint + cumulativePoint;
    }

    function _calculateStakingPoint(uint256 elapsed, uint256 multiplier, uint256 boost) internal pure returns (uint256) {
        return (elapsed * multiplier * boost) / BOOST_MANTISSA;
    }

    function _setUnlockTime(uint256 _unlockTime) internal {
        require(_unlockTime > block.timestamp, "INVALID UNLOCK TIME");
        unlockTime = _unlockTime;
        emit SetUnlockTime(_unlockTime);
    }

    function _getBoost(uint256 count) internal view returns (uint256) {
        if (count > 0 && count < 5) {
            return 500;
        } else if (count >=5 && count < 10) {
            return 600;
        } else {
            return 750;
        }
    }

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
