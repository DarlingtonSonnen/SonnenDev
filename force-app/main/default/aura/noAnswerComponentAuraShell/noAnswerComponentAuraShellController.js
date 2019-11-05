/**
 * Created by m.muchow on 27.03.2019.
 */
({
    refreshView: function(cmp, event) {
        $A.get('e.force:refreshView').fire();
    }
})