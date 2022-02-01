pragma solidity ^0.6.6;

import "./aave/FlashLoanReceiverBase.sol";
import "./aave/ILendingPoolAddressesProvider.sol";
import "./aave/ILendingPool.sol";

contract Flashloan is FlashLoanReceiverBase {
  constructor (address _addressProvider) FlashLoanReceiverBase(_addressProvider) public {}

  event Log(string message, uint256 value);
  event LogAsset(string message, address token);

  struct MyCustomData {
    address token;
    uint256 repayAmount;
    uint256 fullAmount;
    bool isDeposit;
  }

  //
  // Flashloan 1000000000000000000 wei (1 ether) worth of `_asset`
  //

  function flashloan(address _asset, uint256 _amount) public onlyOwner {
    bytes memory data = abi.encode(
      MyCustomData({
      token: _token,
      repayAmount: repayAmount,
      fullAmount: _fullAmount,
      isDeposit: _isDeposit}
    ));

    uint amount = 1 ether;

        // 0 = no debt (flashloan), 1 = stable and 2 = variable
    uint256[] memory modes = new uint256[](1);
    modes[0] = 0;



    ILendingPool lendingPool = ILendingPool(addressProvider.getLendingPool());
    lendingPool.flashLoan(address(this), _asset, amout, data);
    

  }

    function executeOperation(
    address _reserve, 
    uint256 _amount, 
    uint256 fee, // fee instead of _fee
    bytes calldata data
    ) external override {

    require (_amount <= getBalanceInternal(address(this), _reserve), 
    "Invalid balance, was the flashloan success?"
    );
    


    // You can pass in some byte-encoded params
    MyCustomData memory mcd_d = abi.decode(data, (MyCustomData));
    // myCustomData.a
    

    //
    // Here it goes ! 
    //

    uint totalDebt = _amount.add(fee); // _fee ?
    transferFundsBackToPoolInternal(_reserve, totalDebt);
  }


}