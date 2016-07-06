module CPM
  class Calendar
  	def get_calendar  
	    begin
	      calendar = {}

	      calendar_id = Setting.plugin_redmine_cpm[:calendar_id]

	      if calendar_id.present?
	        result = oauth_token.get('https://www.googleapis.com/calendar/v3/calendars/'+calendar_id+'/events?fields=items(summary,start,end)&maxResults=2500')

	        data = JSON.parse(result.body)

	        data['items'].each do |e|
	          pattern = /(.+) - / #/^([\w]+)/
	          matches = pattern.match(e['summary'])

	          if matches.present? and matches[1].present?
	            unless calendar[matches[1]].present?
	              calendar[matches[1]] = []
	            end

	            calendar[matches[1]] << [e['start']['dateTime'].to_date,e['end']['dateTime'].to_date-1.day]
	          end
	        end
	      end
	    rescue
	      calendar = {}
	    end

	    calendar
	  end
  end
end