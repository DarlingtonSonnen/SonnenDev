/**
 * OpportunityAssignPartnerScript
 *
 * @since 2016-11-22
 * @author Marko Schmalenbach <marko@die-interaktiven.de>
 * @see https://interaktiv.jira.com/browse/SOBCRM-681
 */
function opportunityAssignPartnerChangesMade() {
    return (jQuery('button.action-revert-changes:visible').length > 0);
}

function opportunityAssignPartnerConfirmCancel() {

    if (opportunityAssignPartnerChangesMade()) {
        return confirm('Discard changes?');
    }
    return true;
}

jQuery(document).ready(function() {

    var selectors = {
        directSalesCheckbox: 'input.checkbox-assign-direct-sales',
        assignedPartnerLookup: 'input.assigned-partner-lookup',
        proposalsWrapper: 'div.partner-proposals-wrapper',
        column: {
            assignedPartner: 'td.opportunity-column-assigned-partner'
        },
        button: {
            revert:   'button.action-revert-changes',
            proposal: 'button.action-show-proposals',
            accept:   'button.action-confirm',
            acceptAll: '#opportunity-accept-all-button'
        }
    };

    /**
     * Check on changes per row and toggle revert button
     */
    function checkOnChanges() {

        jQuery('table.opportunity-table > tbody > tr').each(function() {

            var $row = jQuery(this);

            // If this is trigger via an event we have to wait until all
            // event handlers have been executed
            window.setTimeout(function() {

                var
                    // Assigned Partner
                    $tableColumnAssignedPartner = $row.find(selectors.column.assignedPartner),
                    $buttonRevertChanges = $row.find(selectors.button.revert),
                    $lookupInput = $tableColumnAssignedPartner.find(selectors.assignedPartnerLookup),
                    $lookupInputId = $tableColumnAssignedPartner.find('input[name$="_lkid"]'),
                    currentPartnerId = $lookupInputId.val().substring(0, 15),
                    initialPartnerId = $tableColumnAssignedPartner.attr('data-partner-id').substring(0, 15), // shorten to 15-digit ID
                    changedAssignedPartner = ($lookupInput.val().length && initialPartnerId != currentPartnerId) ? true : false,

                    // Direct Sales
                    $elementsToToggle = $row.find('td.opportunity-column-recommended-partner, ' + selectors.column.assignedPartner).children(),
                    $directSalesSelectWrapper = $row.find(selectors.column.assignedPartner + ' div.direct-sales-select-wrapper'),
                    $directSalesCheckbox = $row.find(selectors.directSalesCheckbox),
                    $buttonProposal = $row.find(selectors.button.proposal),
                    initialIsDirectSales = $directSalesCheckbox.attr('data-initial-value') == 'true' ? true : false,
                    directSalesChecked = $directSalesCheckbox.prop('checked') ? true : false,
                    changedDirectSales = (directSalesChecked != initialIsDirectSales);

                // Direct Sales
                if (directSalesChecked) {
                    $elementsToToggle.hide();
                    $directSalesSelectWrapper.show();
                    $buttonProposal.prop('disabled', true);
                    $buttonProposal.addClass('btnDisabled');
                }
                else {
                    $elementsToToggle.show();
                    $directSalesSelectWrapper.hide();
                    if (!$buttonProposal.hasClass('no-proposals')) {
                        $buttonProposal.prop('disabled', false);
                        $buttonProposal.removeClass('btnDisabled');
                    }
                }

                // Button "Revert changes"
                var hasChange = (changedAssignedPartner || changedDirectSales),
                    $buttonRevert = $row.find(selectors.button.revert),
                    $buttonSave = jQuery('.command-save');

                $row.find('input[data-type="hasChange"]').val(hasChange);
                hasChange ? $buttonRevert.show() : $buttonRevert.hide();

                if (opportunityAssignPartnerChangesMade()) {
                    $buttonSave.prop('disabled', false);
                    $buttonSave.removeClass('btnDisabled');
                }
                else {
                    $buttonSave.prop('disabled', true);
                    $buttonSave.addClass('btnDisabled');
                }

                // Toggle "Accept all" button
                toggleAcceptAll();

            }, 10);
        });
    }

    /**
     * Sets a selected partner in the corresponding
     * Salesforce inputs
     */
    function setAssignedPartner($element, partnerName, partnerId) {

        var $row = $element.closest('tr'),
            $tableColumn = $row.find(selectors.column.assignedPartner),
            modified = 1;

        $inputLinkId = $tableColumn.find('input[name$="_lkid"]');
        $inputLinkOld = $tableColumn.find('input[name$="_lkold"]');
        $inputLinkMod = $tableColumn.find('input[name$="_mod"]');
        $lookupInput = $tableColumn.find(selectors.assignedPartnerLookup);

        // If partnerId not set reset to former values
        if (!partnerId) {
            partnerName = $tableColumn.attr('data-partner-name');
            partnerId = $tableColumn.attr('data-partner-id');
            modified = 0;
        }

        $lookupInput.val(partnerName);
        $inputLinkId.val(partnerId);
        $inputLinkOld.val(partnerName);
        $inputLinkMod.val(modified);

        checkOnChanges();
    }

    /**
     * Toggle the partner proposals
     */
    function toggleProposals() {

        jQuery(selectors.button.proposal).each(function() {

            var $button = jQuery(this),
                status = $button.attr('data-status'),
                $proposal = $button.closest('td').find(selectors.proposalsWrapper);

            if (status == 'hidden') {
                $proposal.hide();
                $button.find('.label-show').show();
                $button.find('.label-hide').hide();
            }
            else {
                $proposal.show();
                $button.find('.label-show').hide();
                $button.find('.label-hide').show();

                // Set select status
                var accountIdSelected = $button.closest('tr').find('input[name$="_lkid"]').val(),
                    $preselectedRow = $proposal.find('tr[data-partner-id^="' + accountIdSelected + '"]'),
                    cssClassSelected = 'selected';

                // Reset on start
                $proposal.find('tr').removeClass(cssClassSelected);
                $preselectedRow.addClass(cssClassSelected);
            }
        });
    }

    /**
     * On change of Direct Sales setting
     */
    function onChangeDirectSalesTeamSelect() {

        var $select = jQuery(this),
            $row = $select.closest('tr'),
            value = $select.val(),
            $ambassadorSelectWrapper = $row.find('.direct-sales-ambassador-select-wrapper');

        if (value == 'Ambassador') {
            $ambassadorSelectWrapper.show();
        }
        else {
            $ambassadorSelectWrapper.hide();
        }
        checkOnChanges();
    }

    /**
     * Toggle the "Accept all" Button for assigned partner proposals
     */
    function toggleAcceptAll() {

        var $buttonAcceptAll = jQuery(selectors.button.acceptAll),
            $buttonsAccept = jQuery('table.opportunity-table ' + selectors.button.accept),
            acceptButtonsShownCount = $buttonsAccept.filter(':visible').length,
            acceptButtonsCount = $buttonsAccept.length;

        if (acceptButtonsShownCount) {
            $buttonAcceptAll.show();
        }
        else {
            $buttonAcceptAll.hide();
        }
    }

    // Initially check for changes

    // On select "Direct Sales"
    jQuery(selectors.directSalesCheckbox).each(function() {
        jQuery(this).on('click', checkOnChanges);
    });

    // On change of lookup field for Assigned Partner
    jQuery(selectors.column.assignedPartner + ' ' + selectors.assignedPartnerLookup).each(function() {
        jQuery(this).on('change', checkOnChanges);
    });

    // Set id for "Direct Sales" checkbox and corresponding label
    jQuery('.assign-direct-sales-wrapper').each(function() {
        var $checkbox = jQuery(this).find('input'),
            id = $checkbox.attr('data-id'),
            $label = jQuery(this).find('label');

        $checkbox.attr('id', id);
        $label.attr('for', id);
    });

    // Set partner on proposal row click
    jQuery(selectors.proposalsWrapper + ' tr[data-partner-id]').on('click', function() {
        var $row = jQuery(this);
        setAssignedPartner($row.closest('td.opportunity-column-actions'), $row.attr('data-partner-name'), $row.attr('data-partner-id'));
        jQuery(document).trigger('click');
    });

    // Hide any open proposal box on click outside such boxes and their triggering buttons
    jQuery(document).on('click', function(event) {
        if (!jQuery(event.target).closest(selectors.proposalsWrapper).length &&
            !jQuery(event.target).closest(selectors.button.proposal).length) {

            // Reset all button statuses and hide proposals by that
            jQuery(selectors.button.proposal).attr('data-status', 'hidden');
            toggleProposals();
        }
    });

    // On change Direct Sales team select
    jQuery('select.direct-sales-team-select')
        .on('change', onChangeDirectSalesTeamSelect)
        .each(onChangeDirectSalesTeamSelect);

    // Button "Accept all"
    jQuery(selectors.button.acceptAll).appendTo('th.opportunity-column-recommended-partner div').on('click', function() {
        jQuery(this).closest('table').find(selectors.button.accept).trigger('click');
    });
    toggleAcceptAll();

    // Button "Confirm"
    jQuery(selectors.button.accept).on('click', function() {
        var $button = jQuery(this);
        setAssignedPartner($button, $button.attr('data-partner-name'), $button.attr('data-partner-id'));
    });

    // Button "Revert"
    jQuery(selectors.button.revert).on('click', function() {

        var $button = jQuery(this),
            $row = $button.closest('tr'),
            $assignDirectSalesInput = $row.find(selectors.directSalesCheckbox);

        if ($assignDirectSalesInput.prop('checked')) {
            $assignDirectSalesInput.trigger('click');
        }

        setAssignedPartner($button);
    });

    // Button "Proposals"
    jQuery(selectors.button.proposal).on('click', function(event) {

        var $button = jQuery(this),
            status = $button.attr('data-status');

        // Reset all button statuses
        jQuery(selectors.button.proposal).attr('data-status', 'hidden');

        // Set the current button's status
        $button.attr('data-status', status == 'hidden' ? 'show' : 'hidden');

        toggleProposals();
    });
});
