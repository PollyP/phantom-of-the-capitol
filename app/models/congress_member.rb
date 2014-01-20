class CongressMember < ActiveRecord::Base
  validates_presence_of :bioguide_id

  has_many :actions, :class_name => 'CongressMemberAction', :dependent => :destroy
  has_many :required_actions, :class_name => 'CongressMemberAction', :conditions => "required = 1"
  #has_one :captcha_action, :class_name => 'CongressMemberAction', :condition => "value = '$CAPTCHA_SOLUTION'"
  
  def self.bioguide bioguide_id
    find_by_bioguide_id bioguide_id
  end

  def self.with_existing_bioguide bioguide_id
    yield find_by_bioguide_id bioguide_id
  end

  def self.with_new_bioguide bioguide_id
    yield self.create :bioguide_id => bioguide_id
  end

  def self.with_new_or_existing_bioguide bioguide_id
    yield self.find_or_create_by_bioguide_id bioguide_id
  end

  def as_required_json o={}
    as_json({
      :only => [],
      :include => {:required_actions => CongressMemberAction::REQUIRED_JSON}
    }.merge o)
  end

  def fill_out_form f={}
    headless = Headless.new
    headless.start
    b = Watir::Browser.new
    actions.order(:step).each do |a|
      case a.action
      when "visit"
        b.goto a.value
      when "fill_in"
        b.element(:css => a.selector).to_subtype.set(f[a.value]) unless f[a.value].nil?
      when "select"
        b.element(:css => a.selector).to_subtype.select(f[a.value]) unless f[a.value].nil?
      when "click_on"
        b.element(:css => a.selector).to_subtype.click
      when "find"
        b.element(:css => a.selector).wait_until_present
      when "check"
        b.element(:css => a.selector).to_subtype.set
      when "uncheck"
        b.element(:css => a.selector).to_subtype.clear
      when "choose"
        b.element(:css => a.selector).to_subtype.set
      end
    end
    retval = check_success b
    b.close
    headless.destroy
    retval
  end
  
  def check_success b
    criteria = YAML.load(success_criteria)
    criteria.each do |i, v|
      case i
      when "headers"
        v.each do |hi, hv|
          case hi
          when "status"
            # TODO: check status code
          end
        end
      when "body"
        v.each do |bi, bv|
          case bi
          when "contains"
            unless b.text.include? bv
              return false
            end
          end
        end
      end
    end
    true
  end
end
