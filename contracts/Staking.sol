// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.17;

import "./libraries/SafeMath.sol";
import "./libraries/SafeERC20.sol";

import "./interfaces/IERC20.sol";
import "./interfaces/IsGNOME.sol";
import "./interfaces/IgGNOME.sol";
import "./interfaces/IDistributor.sol";

import "./types/GnomeAccessControlled.sol";

contract GnomeStaking is GnomeAccessControlled {
    /* ========== DEPENDENCIES ========== */

    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IsGNOME;
    using SafeERC20 for IgGNOME;

    /* ========== EVENTS ========== */

    event DistributorSet(address distributor);
    event WarmupSet(uint256 warmup);

    /* ========== DATA STRUCTURES ========== */

    struct Epoch {
        uint256 length; // in seconds
        uint256 number; // since inception
        uint256 end; // timestamp
        uint256 distribute; // amount
    }

    struct Claim {
        uint256 deposit; // if forfeiting
        uint256 gons; // staked balance
        uint256 expiry; // end of warmup period
        bool lock; // prevents malicious delays for claim
    }

    /* ========== STATE VARIABLES ========== */

    IERC20 public immutable GNOME;
    IsGNOME public immutable sGNOME;
    IgGNOME public immutable gGNOME;

    Epoch public epoch;

    IDistributor public distributor;

    mapping(address => Claim) public warmupInfo;
    uint256 public warmupPeriod;
    uint256 private gonsInWarmup;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _gnome,
        address _sGNOME,
        address _gGNOME,
        uint256 _epochLength,
        uint256 _firstEpochNumber,
        uint256 _firstEpochTime,
        address _authority
    ) GnomeAccessControlled(IGnomeAuthority(_authority)) {
        require(_gnome != address(0), "Zero address: GNOME");
        GNOME = IERC20(_gnome);
        require(_sGNOME != address(0), "Zero address: sGNOME");
        sGNOME = IsGNOME(_sGNOME);
        require(_gGNOME != address(0), "Zero address: gGNOME");
        gGNOME = IgGNOME(_gGNOME);

        epoch = Epoch({
            length: _epochLength,
            number: _firstEpochNumber,
            end: _firstEpochTime,
            distribute: 0
        });
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice stake GNOME to enter warmup
     * @param _to address
     * @param _amount uint
     * @param _claim bool
     * @param _rebasing bool
     * @return uint
     */
    function stake(
        address _to,
        uint256 _amount,
        bool _rebasing,
        bool _claim
    ) external returns (uint256) {
        GNOME.safeTransferFrom(msg.sender, address(this), _amount);
        _amount = _amount.add(rebase()); // add bounty if rebase occurred
        if (_claim && warmupPeriod == 0) {
            return _send(_to, _amount, _rebasing);
        } else {
            Claim memory info = warmupInfo[_to];
            if (!info.lock) {
                require(
                    _to == msg.sender,
                    "External deposits for account are locked"
                );
            }

            warmupInfo[_to] = Claim({
                deposit: info.deposit.add(_amount),
                gons: info.gons.add(sGNOME.gonsForBalance(_amount)),
                expiry: epoch.number.add(warmupPeriod),
                lock: info.lock
            });

            gonsInWarmup = gonsInWarmup.add(sGNOME.gonsForBalance(_amount));

            return _amount;
        }
    }

    /**
     * @notice retrieve stake from warmup
     * @param _to address
     * @param _rebasing bool
     * @return uint
     */
    function claim(address _to, bool _rebasing) public returns (uint256) {
        Claim memory info = warmupInfo[_to];

        if (!info.lock) {
            require(
                _to == msg.sender,
                "External claims for account are locked"
            );
        }

        if (epoch.number >= info.expiry && info.expiry != 0) {
            delete warmupInfo[_to];

            gonsInWarmup = gonsInWarmup.sub(info.gons);

            return _send(_to, sGNOME.balanceForGons(info.gons), _rebasing);
        }
        return 0;
    }

    /**
     * @notice forfeit stake and retrieve GNOME
     * @return uint
     */
    function forfeit() external returns (uint256) {
        Claim memory info = warmupInfo[msg.sender];
        delete warmupInfo[msg.sender];

        gonsInWarmup = gonsInWarmup.sub(info.gons);

        GNOME.safeTransfer(msg.sender, info.deposit);

        return info.deposit;
    }

    /**
     * @notice prevent new deposits or claims from ext. address (protection from malicious activity)
     */
    function toggleLock() external {
        warmupInfo[msg.sender].lock = !warmupInfo[msg.sender].lock;
    }

    /**
     * @notice redeem sGNOME for GNOMEs
     * @param _to address
     * @param _amount uint
     * @param _trigger bool
     * @param _rebasing bool
     * @return amount_ uint
     */
    function unstake(
        address _to,
        uint256 _amount,
        bool _trigger,
        bool _rebasing
    ) external returns (uint256 amount_) {
        amount_ = _amount;
        uint256 bounty;
        if (_trigger) {
            bounty = rebase();
        }
        if (_rebasing) {
            sGNOME.safeTransferFrom(msg.sender, address(this), _amount);
            amount_ = amount_.add(bounty);
        } else {
            gGNOME.burn(msg.sender, _amount); // amount was given in gGNOME terms
            amount_ = gGNOME.balanceFrom(amount_).add(bounty); // convert amount to GNOME terms & add bounty
        }

        require(
            amount_ <= GNOME.balanceOf(address(this)),
            "Insufficient GNOME balance in contract"
        );
        GNOME.safeTransfer(_to, amount_);
    }

    /**
     * @notice convert _amount sGNOME into gBalance_ gGNOME
     * @param _to address
     * @param _amount uint
     * @return gBalance_ uint
     */
    function wrap(address _to, uint256 _amount)
        external
        returns (uint256 gBalance_)
    {
        sGNOME.safeTransferFrom(msg.sender, address(this), _amount);
        gBalance_ = gGNOME.balanceTo(_amount);
        gGNOME.mint(_to, gBalance_);
    }

    /**
     * @notice convert _amount gGNOME into sBalance_ sGNOME
     * @param _to address
     * @param _amount uint
     * @return sBalance_ uint
     */
    function unwrap(address _to, uint256 _amount)
        external
        returns (uint256 sBalance_)
    {
        gGNOME.burn(msg.sender, _amount);
        sBalance_ = gGNOME.balanceFrom(_amount);
        sGNOME.safeTransfer(_to, sBalance_);
    }

    /**
     * @notice trigger rebase if epoch over
     * @return uint256
     */
    function rebase() public returns (uint256) {
        uint256 bounty;
        if (epoch.end <= block.timestamp) {
            sGNOME.rebase(epoch.distribute, epoch.number);

            epoch.end = epoch.end.add(epoch.length);
            epoch.number++;

            if (address(distributor) != address(0)) {
                distributor.distribute();
                bounty = distributor.retrieveBounty(); // Will mint GNOME for this contract if there exists a bounty
            }
            uint256 balance = GNOME.balanceOf(address(this));
            uint256 staked = sGNOME.circulatingSupply();
            if (balance <= staked.add(bounty)) {
                epoch.distribute = 0;
            } else {
                epoch.distribute = balance.sub(staked).sub(bounty);
            }
        }
        return bounty;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    /**
     * @notice send staker their amount as sGNOME or gGNOME
     * @param _to address
     * @param _amount uint
     * @param _rebasing bool
     */
    function _send(
        address _to,
        uint256 _amount,
        bool _rebasing
    ) internal returns (uint256) {
        if (_rebasing) {
            sGNOME.safeTransfer(_to, _amount); // send as sGNOME (equal unit as GNOME)
            return _amount;
        } else {
            gGNOME.mint(_to, gGNOME.balanceTo(_amount)); // send as gGNOME (convert units from GNOME)
            return gGNOME.balanceTo(_amount);
        }
    }

    /* ========== VIEW FUNCTIONS ========== */

    /**
     * @notice returns the sGNOME index, which tracks rebase growth
     * @return uint
     */
    function index() public view returns (uint256) {
        return sGNOME.index();
    }

    /**
     * @notice total supply in warmup
     */
    function supplyInWarmup() public view returns (uint256) {
        return sGNOME.balanceForGons(gonsInWarmup);
    }

    /**
     * @notice seconds until the next epoch begins
     */
    function secondsToNextEpoch() external view returns (uint256) {
        return epoch.end.sub(block.timestamp);
    }

    /* ========== MANAGERIAL FUNCTIONS ========== */

    /**
     * @notice sets the contract address for LP staking
     * @param _distributor address
     */
    function setDistributor(address _distributor) external onlyGovernor {
        distributor = IDistributor(_distributor);
        emit DistributorSet(_distributor);
    }

    /**
     * @notice set warmup period for new stakers
     * @param _warmupPeriod uint
     */
    function setWarmupLength(uint256 _warmupPeriod) external onlyGovernor {
        warmupPeriod = _warmupPeriod;
        emit WarmupSet(_warmupPeriod);
    }
}
