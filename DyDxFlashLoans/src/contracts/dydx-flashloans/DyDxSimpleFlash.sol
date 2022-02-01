// DyDxSimpleFlash.sol

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/DyDxFlashloanBase.sol";
import "./interfaces/ICallee.sol";
import "./interfaces/ICToken.sol";

interface Comptroller {
  function enterMarkets(address[] calldata) external returns (uint256[] memory);
  function claimComp(address holder) external;
}

contract SimpleDyDxFlashloan is DydxFlashloanBase, ICallee {
    // Mainnet Dai
    // https://etherscan.io/address/0x6b175474e89094c44da98b954eedeac495271d0f#readContract
    address private constant daiAddress = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    IERC20 dai = IERC20(daiAddress);

    // Mainnet cDai
    // https://etherscan.io/address/0x5d3a536e4d6dbd6114cc1ead35777bab948e3643#readProxyContract
    address private constant cDaiAddress = 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643;
    ICToken cDai = ICToken(cDaiAddress);

    // Mainnet Comptroller
    // https://etherscan.io/address/0x3d9819210a31b4961b30ef54be2aed79b9c9cd3b#readProxyContract
    address private constant comptrollerAddress = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    Comptroller comptroller = Comptroller(comptrollerAddress);

    // COMP ERC-20 token
    // https://etherscan.io/token/0xc00e94cb662c3520282e6f5717214004a7f26888
    IERC20 compToken = IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888);

    address SOLO = 0x1E0447b19BB6EcFdAe1e4AE1694b0C3659614e4e;
    address public user;
    address owner;

    event Log(string message, uint256 val);

    struct Data {
        address token;
        uint256 repayAmount;
        uint256 fullAmount;
        bool isDeposit;
    }

        // Modifiers
    modifier onlyOwner() {
      require(msg.sender == owner, "caller is not the owner!");
      _;
    }

  constructor() {
    // Track the contract owner
    owner = msg.sender;

    // Enter the cDai market so you can borrow another type of asset
    address[] memory cTokens = new address[](1);
    cTokens[0] = cDaiAddress;
    uint256[] memory errors = comptroller.enterMarkets(cTokens);
    if (errors[0] != 0) {
      revert("Comptroller.enterMarkets failed.");
    }
  }
    // Call dydx and request a flashloan
    function initiateFlashloan(address _solo, address _token, uint256 _amount, uint256 _fullAmount, bool _isDeposit) internal {
        ISoloMargin solo = ISoloMargin(_solo);

        // Get Market ID from token address
        uint256 marketID = _getMarketIdFromTokenAddress(_solo, _token);

        // Calculate repay amount & approve
        uint256 repay_amount = _getRepaymentAmountInternal(_amount);
        IERC20(_token).approve(_solo, repay_amount);

        // 1. Withdraw $
        // 2. Call callFunction (...)
        // 3. Deposit back $

        Actions.ActionArgs[] memory operations = new Actions.ActionArgs[](3);

        operations[0] = _getWithdrawAction(marketID, _amount);
        // Encode Data for callfunction
        operations[1] = _getCallAction(
            abi.encode(Data({token: _token, repayAmount: repay_amount, fullAmount: _fullAmount, isDeposit: _isDeposit}))
        );
        operations[2] = _getDepositAction(marketID, repay_amount);

        Account.Info[] memory accountInfos = new Account.Info[](1);

        accountInfos[0] = _getAccountInfo();

        solo.operate(accountInfos, operations);
    }

    // Do not deposit all your DAI because you must pay flash loan fees
    // Always keep at least 1 DAI in the contract
    function depositDai(uint256 initialAmount) external onlyOwner returns (bool) {
      // Total deposit: 30% initial amount, 70% flash loan
      uint256 totalAmount = (initialAmount * 10) / 3;

      // loan is 70% of total deposit
      uint256 flashLoanAmount = totalAmount - initialAmount;

      // Get DAI Flash Loan for "DEPOSIT"
      bool isDeposit = true;
      initiateFlashloan(SOLO, daiAddress, flashLoanAmount, totalAmount, isDeposit); // execution goes to `callFunction`

      // Handle remaining execution inside handleDeposit() function

      return true;
    }

    // You must have some Dai in your contract still to pay flash loan fee!
    // Always keep at least 1 DAI in the contract
    function withdrawDai(uint256 initialAmount) external onlyOwner returns (bool) {
      // Total deposit: 30% initial amount, 70% flash loan
      uint256 totalAmount = (initialAmount * 10) / 3;

      // loan is 70% of total deposit
      uint256 flashLoanAmount = totalAmount - initialAmount;

      // Use flash loan to payback borrowed amount
      bool isDeposit = false; //false means withdraw
      initiateFlashloan(SOLO, daiAddress, flashLoanAmount, totalAmount, isDeposit); // execution goes to `callFunction`

      // Handle repayment inside handleWithdraw() function

      // Claim COMP tokens
      comptroller.claimComp(address(this));

      // Withdraw COMP tokens
      compToken.transfer(payable(owner), compToken.balanceOf(address(this)));

      // Withdraw Dai to the wallet
      dai.transfer(owner, dai.balanceOf(address(this)));

      return true;
    }

    // This function receives the flashloan
    // Fallback function called by dydx
    function callFunction(
        address sender,
        Account.Info memory account,
        bytes memory data
    ) public override {
        require(
            msg.sender == SOLO,
            "the caller to this function is not SOLO contract"
        );
        require(
            sender == address(this),
            "sender of the flashloan has to be the address of dydxFlashloan"
        );

        Data memory data_decoded = abi.decode(data, (Data));

        uint256 repay_amount = data_decoded.repayAmount;
        uint256 balance = IERC20(data_decoded.token).balanceOf(address(this));
        
        require(
            balance >= repay_amount,
            "balance has to be higher than repay amount"
        );

        if(data_decoded.isDeposit == true) {
          handleDeposit(data_decoded.fullAmount, data_decoded.repayAmount);
        }

        if(data_decoded.isDeposit == false) {
          handleWithdraw();
        }

        user = sender;
        emit Log("balance", balance);
        emit Log("repay amount", repay_amount);
        emit Log("balance - repay amount", balance - repay_amount);
    }

  // You must first send DAI to this contract before you can call this function
  function handleDeposit(uint256 totalAmount, uint256 flashLoanAmount) internal returns (bool) {
    // Approve Dai tokens as collateral
    dai.approve(cDaiAddress, totalAmount);

    // Provide collateral by minting cDai tokens
    cDai.mint(totalAmount);

    // Borrow Dai
    cDai.borrow(flashLoanAmount);

    // Start earning COMP tokens, yay!
    return true;
  }

  function handleWithdraw() internal returns (bool) {
    uint256 balance;

    // Get curent borrow Balance
    balance = cDai.borrowBalanceCurrent(address(this));

    // Approve tokens for repayment
    dai.approve(address(cDai), balance);

    // Repay tokens
    cDai.repayBorrow(balance);

    // Get cDai balance
    balance = cDai.balanceOf(address(this));

    // Redeem cDai
    cDai.redeem(balance);

    return true;
  }

  // Fallback in case any other tokens are sent to this contract
  function withdrawToken(address _tokenAddress) public onlyOwner {
    uint256 balance = IERC20(_tokenAddress).balanceOf(address(this));
    IERC20(_tokenAddress).transfer(owner, balance);
  }
}
