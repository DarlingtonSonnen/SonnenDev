var $j = jQuery.noConflict();

PortalAccount = {

    init: function() {

        // Init
        this.initFunnel();

        // Checkboxes (list)
    	this.validateAcceptCheckboxes();

    	// Filter
    	this.initFilterHandler();

        // Datepicker (detail)
        var options = $j.extend({}, $j.datepicker.regional['de'], {
            dateFormat: 'dd.mm.yy',
            minDate   : '+1d'
        });
        $j.datepicker.setDefaults(options);

        $j('.datepicker').each(function() {

            var $altField = $j(this).parent().find('input[data-datepicker-hidden]');

            //console.log($altField.val());

            $j(this)
            .datepicker({
                altField: $altField,
                altFormat: 'yy-mm-dd'
            })
            .datepicker('setDate', new Date(Date.parse($altField.val()))); // Init by saved value
        });

        // SBC status change (detail)
        $j('select.sbc-status').on('change', this.handleStatusChange).trigger('change');

        // Add hash to URL to jump to the block of the clicked pagination
        $j('.pagination-item a').on('click', function() {

            var urlHashName = 'headline-' + $j(this).closest('div.apexp').attr('data-blockname'),
                parser = document.createElement('a');

            parser.href = $j(this).attr('href');
            parser.hash = urlHashName;

            $j(this).attr('href', parser.search + parser.hash);
        });
    },

    /**
     * Init the funnel
     */
    initFunnel: function() {

        if (typeof funnelData == 'undefined') {
            return;
        }

        var sum = 0;
        for (var i in funnelData) {
        	sum += funnelData[i].y;
        }

        if (!sum) {
            return;
        }

        var $funnelChart = $j('#funnel-chart');

        if ($funnelChart.length) {

            $funnelChart.highcharts({
                chart: {
                    type: 'funnel',
                    marginRight: 150,
                    height: 200,
                    width: 400
                },
                title: {
                    text: 'Leads - \u00dcbersicht',
                    x: -100
                },
                plotOptions: {
                    series: {
                        dataLabels: {
                            enabled: true,
                            format: '<b>{point.name}</b> ({point.y:,.0f})',
                            color: (Highcharts.theme && Highcharts.theme.contrastTextColor) || 'black',
                            softConnector: true
                        },
                        neckWidth: '30%',
                        neckHeight: '25%'

                        //-- Other available options
                        // height: pixels or percent
                        // width: pixels or percent
                    }
                },
                legend: {
                    enabled: false
                },
                series: [{
                    name: 'Leads',
                    data: funnelData
                }]
            });

            $funnelChart.fadeIn();
        }

    },

    /**
     * Handle SBC status change
     */
    handleStatusChange: function() {

        var value = $j(this).val();

        // Show container according to SBC status
        $j('.status-dependent-container').each(function() {

            var $container = $j(this),
                status = $container.attr('data-dependent-status').split(',');

            if ($j.inArray(value, status) != -1) {
            	$container.show();
            }
            else {
            	$container.hide();
            }
        });
    },

    /**
     * Validate accept checkboxes
     *
     * @param object Checkbox
     */
    validateAcceptCheckboxes: function(checkbox) {

        var $acceptButtons = $j('.accept-button'),
            masterCheckboxId = 'toggle-accept-checkbox',
            acceptCount = acceptCheckedCount = 0,
            clickedIsMaster = checked = false;

        if (checkbox) {
        	var $currentCheckbox = $j(checkbox);
            clickedIsMaster = ($currentCheckbox.attr('id') == masterCheckboxId);
            checked = $currentCheckbox.prop('checked');
        }

        $j('input.accept-checkbox').each(function() {

            acceptCount++;

            if (clickedIsMaster) {
                $j(this).prop('checked', checked);
                checked && acceptCheckedCount++;
            }
            else {
                $j(this).prop('checked') && acceptCheckedCount++;
            }
        });

        if (!clickedIsMaster) {
			$j('#' + masterCheckboxId).prop('checked', acceptCount == acceptCheckedCount);
        }

        var disableButton = (acceptCheckedCount == 0);
        $acceptButtons.prop('disabled', disableButton);

        if (disableButton) {
			$acceptButtons.removeClass('btn');
			$acceptButtons.addClass('btnDisabled');
        }
        else {
			$acceptButtons.removeClass('btnDisabled');
			$acceptButtons.addClass('btn');
        }
    },

    initFilterHandler: function() {

        var self = this;

        $j('.record-filter').each(function() {

            var $filter = $j(this),
                $filterQuery = $filter.find('.record-filter-query-default'),
                $filterField = $filter.find('.record-filter-field'),
                $filterReset = $filter.find('.record-filter-reset'),
                $currentFilterQuery = $filterQuery,
                hasActiveFilter = ($filterField.attr('data-selected') != '');

            // Do not show filter if nothing was filtered and there
            // are at least 2 records
            if (parseInt($filter.attr('data-count')) < 2 && !hasActiveFilter) {
                return;
            }

            $filter.show();

            // Show reset if a field is selected
            if (hasActiveFilter) {
                $filterReset.show();
            }

            // Set current selected filter field
            $filterField.val($filterField.attr('data-selected'));

            // Filter reset onclick
            $filterReset.on('click', function() {

                var parameters = self.getUrlParameters();

                delete parameters[$filterField.attr('name')];
                delete parameters[$filterQuery.attr('name')];

                $filterQuery.val('');
                $filterReset.hide();

                // Reload page with new filter
                window.location.search = self.buildQueryString(parameters);
            });

            var onFilterFieldSelect = function() {

                var queryFieldSelector = $filterField.find('option:selected').attr('data-queryfield');

                $currentFilterQuery.hide();
                $currentFilterQuery = queryFieldSelector ? $filter.find(queryFieldSelector) : $filterQuery;
                $currentFilterQuery.show();
            };

            onFilterFieldSelect();

            // Set data-selected on current filter query element (if attribute available)
            if ($currentFilterQuery.attr('data-selected')) {
                $currentFilterQuery.val($currentFilterQuery.attr('data-selected'));
            }

            // On filter field select
            $filterField.on('change', onFilterFieldSelect);

            // Filter button onclick
            $filter.on('submit', function() {

                var query = $j.trim($currentFilterQuery.val());

                if (!query.length && !$filterField.find('option:selected').attr('data-nullable')) {
                    alert('Bitte geben Sie einen Suchbegriff ein!');
                    $currentFilterQuery.focus();
                    return false;
                }

                var parameters = self.getUrlParameters();

                parameters[$filterField.attr('name')] = $filterField.val();
                parameters[$filterQuery.attr('name')] = $currentFilterQuery.val();

                // Drop pagination parameter
                var filterNameAbbreviation = $j(this).closest('div[data-blockname-abbr]').attr('data-blockname-abbr'),
                    paginationPageParameter = filterNameAbbreviation + 'Page';

                if (parameters[paginationPageParameter]) {
                    delete parameters[paginationPageParameter];
                }

                // Reload page with new filter
                window.location.search = self.buildQueryString(parameters);
                return false;
            });
        });
    },

    buildQueryString: function(parameters) {

        var queryParts = [];

        for (var field in parameters) {
            queryParts.push(field + '=' + encodeURIComponent(parameters[field]));
        }

        return queryParts.join('&');
    },

    getUrlParameters: function() {

        var search = window.location.search.substring(1),
            parameters = search ? JSON.parse(
                '{"' + search.replace(/&/g, '","').replace(/=/g, '":"') + '"}',
                function (key, value) {
                    return key === "" ? value : decodeURIComponent(value)
                }) : {};

        return parameters;
    }
};

$j(document).ready(function() {
	PortalAccount.init();
});