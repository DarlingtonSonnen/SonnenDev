/**
 * Created by m.muchow on 02.09.2019.
 */

({
    refreshView: function(cmp, event) {
        $A.get('e.force:refreshView').fire();
    }
})