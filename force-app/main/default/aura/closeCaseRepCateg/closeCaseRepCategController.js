/**
 * Created by a.romero on 09/08/2019.
 */

({
    refreshView: function(cmp, event) {
        $A.get('e.force:refreshView').fire();
    }
});