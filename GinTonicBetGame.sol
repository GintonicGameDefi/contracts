// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBEP20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the token decimals.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Returns the token symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the token name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external view returns (address);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address _owner, address spender)
        external
        view
        returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

contract GinTonicBetGame {
    string public name = "GinTonic Bet Game";
    address public prizesWalletAddress;
    address public burnAddress;
    IBEP20 public gintonicToken;

    address public admin;
    uint256 public gameId;
    uint256 public lastGameId;
    uint256 public minBetAmount = 50 * 10**8;
    mapping(uint256 => Game) public games;

    struct Game {
        uint256 id;
        uint256 bet;
        uint256 seed;
        uint256 amount;
        address player;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "caller is not the admin");
        _;
    }

    event Withdraw(address indexed admin, uint256 amount);
    event Result(
        uint256 id,
        uint256 bet,
        uint256 randomSeed,
        uint256 amount,
        address player,
        uint256 winAmount,
        uint256 feeAmount,
        uint256 burnAmount,
        uint256 randomResult,
        uint256 time
    );

    constructor(
        address _gintonicToken,
        address _prizesWalletAddress,
        address _burnAddress
    ) {
        gintonicToken = IBEP20(_gintonicToken);
        prizesWalletAddress = _prizesWalletAddress;
        burnAddress = _burnAddress;
        admin = msg.sender;
    }

    function game(uint256 bet, uint256 betAmount, uint256 seed) external returns (bool) {
        /** !UPDATE
         *
         * Checking if betAmount is higher or equal than [minBetAmount] GINTONIC.
         */
        require(
            betAmount >= minBetAmount,
            "Error, betAmount must be equal or greater than minimum bet amount."
        );

        //  bet should be 0 ~ 9
        require(bet < 10, "Error, accept only 0 ~ 9");

        // vault balance must be at least equal to betAmount
        require(
            gintonicToken.balanceOf(address(this)) >= betAmount,
            "Error, insufficent vault balance"
        );

        // the game contract receives GINTONIC from player
        require(
            gintonicToken.transferFrom(msg.sender, address(this), betAmount),
            "GINTONIC send failed."
        );

        //each bet has unique id
        games[gameId] = Game(gameId, bet, seed, betAmount, msg.sender);

        //increase gameId for the next bet
        gameId = gameId + 1;

        //seed is auto-generated by DApp
        uint256 randomNumber = getRandomNumber(seed);

        // Do the verdict
        verdict(bet, randomNumber);

        return true;
    }

    /**
     * Request for randomness.
     */
    function getRandomNumber(uint256 userProvidedSeed)
        internal
        view
        returns (uint256 randomNumber)
    {
        // Implement the random number generation.
        bytes32 random =
            keccak256(abi.encode(userProvidedSeed, block.timestamp));
        randomNumber = uint256(random) % 10;
    }

    /**
     * Send rewards to the winners.
     */
    function verdict(uint256 bet, uint256 random) internal {
        //check bets from latest betting round, one by one
        for (uint256 i = lastGameId; i < gameId; i++) {
            //reset winAmount for current user
            uint256 winAmount = 0;
            uint256 feeAmount = 0;
            uint256 burnAmount = 0;

            //if user wins, then receives 2x of their betting amount
            if (bet == (random + 8) % 10) {
                winAmount = games[i].amount * 2;
            } else if (bet == (random + 5) % 10) {
                winAmount = (games[i].amount * 15000) / 10000;
            } else if (bet == (random + 0) % 10) {
                winAmount = (games[i].amount * 13000) / 10000;
            } else if (bet == (random + 1) % 10) {
                winAmount = (games[i].amount * 12000) / 10000;
            } else if (
                bet == (random + 9) % 10 ||
                bet == (random + 3) % 10 ||
                bet == (random + 6) % 10 ||
                bet == (random + 4) % 10
            ) {
                winAmount = games[i].amount;
            }

            // Transfer winAmount to user
            if (winAmount > 0) {
                feeAmount = (winAmount * 300) / 10000;
                burnAmount = (winAmount * 200) / 10000;
                winAmount = winAmount - feeAmount - burnAmount;
                gintonicToken.transfer(games[i].player, winAmount);
                gintonicToken.transfer(burnAddress, burnAmount);
                gintonicToken.transfer(prizesWalletAddress, feeAmount);
            }
            emit Result(
                games[i].id,
                games[i].bet,
                games[i].seed,
                games[i].amount,
                games[i].player,
                winAmount,
                feeAmount,
                burnAmount,
                random,
                block.timestamp
            );
        }
        //save current gameId to lastGameId for the next betting round
        lastGameId = gameId;
    }

    /**
     * Withdraw GINTONIC from this contract (admin option).
     */
    function withdrawGINTONIC(uint256 amount) external onlyAdmin {
        require(
            gintonicToken.balanceOf(address(this)) >= amount,
            "Error, contract has insufficent balance"
        );
        gintonicToken.transfer(admin, amount);
        emit Withdraw(admin, amount);
    }

    /**
     * Set min bet amount (admin option).
     */
    function setMinBetAmount(uint256 newMinBetAmount) external onlyAdmin {
        require(newMinBetAmount > 0, "Error, invalid minimum Bet amount");
        minBetAmount = newMinBetAmount;
    }
}
