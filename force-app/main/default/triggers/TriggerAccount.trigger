trigger TriggerAccount on Account (before insert, before update, after insert, after update) {
	new AccountTriggerHandler().run();
}