trigger AssetTrigger on Asset (after insert, before update, before insert) {
    new AssetTriggerHandler().run();
}