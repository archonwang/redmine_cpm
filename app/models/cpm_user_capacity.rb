class CpmUserCapacity < ActiveRecord::Base
	belongs_to :user
  belongs_to :project
  belongs_to :editor, :class_name => "User", :foreign_key => "editor_id"

  unloadable
  validates :capacity, :presence => true, numericality: { only_integer: true }, :inclusion => {:in => (0..100).step(5), :message => " tiene que ser multiplo de 5 comprendido entre 0 y 100."}
  validates :from_date,	:presence => true, 
  						:format => {:with => /^\d{4}-\d{2}-\d{2}/, :message => " tiene que ser una fecha válida" }
  validates :to_date, 	:presence => true, 
  						:format => {:with => /^\d{4}-\d{2}-\d{2}/, :message => " tiene que ser una fecha válida" }
  validate :to_date_after_from_date

  before_save do 
    self.editor_id = User.current.id
  end

  # validates from_date starts before due_date
  def to_date_after_from_date
    if from_date.present? && to_date.present?
      errors.add(:to_date, :msg_to_date_after_from_date) if to_date < from_date
    end
  end

  # send a notice if user's total capacity on a day is higher than 100
  def check_capacity(ignored_projects = [0])
    result = true

    user = User.find_by_id(self.user_id)
    days = (Date.parse(self.to_date.to_s) - Date.parse(self.from_date.to_s)).to_i

    (0..days).each do |i|
      date = self.from_date + i.day

      if get_total_capacity(self.user_id, date, ignored_projects) > 100    
        result = false
      end
    end

    result
  end

  def get_error_message
    error_msg = ""
    
    # get errors list
    self.errors.full_messages.each do |msg|
      if error_msg != ""
        error_msg << "<br>"
      end
      error_msg << msg
    end

    error_msg
  end

  # Array of filter names
  def self.get_filter_names
    project_filters = Setting.plugin_redmine_cpm['project_filters'] || [0]
    custom_field_filters = CustomField.where("id IN (?)",project_filters.map{|e| e.to_s}).collect{|cf| [cf.name,cf.id.to_s]}
    
    filters = [['','default']] + custom_field_filters + ['users','groups','projects','project_manager','time_unit','time_unit_num','ignore_black_lists'].collect{|f| [l(:"cpm.label_#{f}"),f]}

    if Setting.plugin_redmine_cpm['plugin_knowledge_manager'].present?
      filters << [l(:"cpm.label_knowledges"),'knowledges']
    end

    filters
  end

  # Get capacity relative value between start_day and end_day
  def get_relative(start_day, end_day)
    result = 0

    if self.to_date >= start_day and self.from_date <= end_day
      fd = [Date.parse(self.from_date.to_s),start_day].max
      td = [Date.parse(self.to_date.to_s),end_day].min

      if start_day != end_day
        result = (self.capacity*(td - fd + 1).to_f)/(end_day - start_day + 1).to_f
      else
        result = self.capacity.to_f
      end
    end

    result
  end

  # Show user capacity tooltip
  def get_tooltip(start_day, end_day)
    result = ""

    if self.to_date >= start_day and self.from_date <= end_day      
      editor = l(:"cpm.unknown")
      if self.editor.present?
        editor = self.editor.login
      end

      result = CGI::escapeHTML(self.project.name)+": <b>"+(self.capacity).to_s+"%</b>. "+self.from_date.strftime('%d/%m/%y')+" - "+self.to_date.strftime('%d/%m/%y')+". "+l(:"cpm.label_edited_by")+" "+editor+"<br>"
    end

    result
  end

  private
  def get_total_capacity(user_id, date, ignored_projects = [0])
    CpmUserCapacity.where("user_id = ? AND from_date <= ? AND to_date >= ? AND project_id NOT IN (?)", user_id, date, date, ignored_projects).inject(0) { |sum, e| 
      sum += e.capacity  
    }
  end
end
