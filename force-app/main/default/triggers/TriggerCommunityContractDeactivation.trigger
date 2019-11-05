/**
 * Before Update Trigger for Community Contracts - prevents termination of a Community Contract
 * as long as there are related Energy/SonnenFlat Contracts active.
 *
 * @version    2016-12-06 dino.ursic@die-interaktiven.de        SOBCRM-261 - Kündigung Community Stromvertrag berücksichtigen
 *                 
 */ 
trigger TriggerCommunityContractDeactivation on Contract (before update) {
  
  new CommunityContractDeactiveTriggerHandler().run();
  
}