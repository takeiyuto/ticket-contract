const TicketContract = artifacts.require("Tickets");

module.exports = function (deployer) {
  deployer.deploy(TicketContract);
};
