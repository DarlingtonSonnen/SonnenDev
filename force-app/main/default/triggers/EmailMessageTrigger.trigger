/**
 * Created by l.martins on 8/12/2019.
 */

trigger EmailMessageTrigger on EmailMessage (before insert, after insert) {
new EmailMessageTriggerHandler().run();
}