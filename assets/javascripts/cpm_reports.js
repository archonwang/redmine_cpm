$(document).ready(function(){
	$(document).on('change','#report_type',function(){
		value = $('#report_type').val();
		//$('#report_options_div').load('/cpm_management/get_report_options_'+value);
		if (value != ''){
			$.ajax({
				url: '/cpm_reports/get_report_options_'+value,
				//data: data,
				async: false,
				success: function(data){
					$('#report_options_div').html(data['options']);
				}
			});
		} else {
			$('#report_options_div').html("");
		}

	});
});