/**
 * Created by m.muchow on 18.06.2019.
 */

({
    refreshView: function(cmp, event) {
        $A.get('e.force:refreshView').fire();
    }
})