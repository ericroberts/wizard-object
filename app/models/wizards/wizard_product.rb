class WizardProduct < Product
  attr_accessor :step, :steps, :session, :validations

  @@parent = superclass

  def underscored_name
    @@parent.name.underscore
  end

  def self.model_name
    @@parent.model_name
  end
  
  def save
    valid?
    
    remove_errors_from_other_steps
    
    if errors.empty?

      if step == steps.last
        obj = @@parent.new(accessible_attributes)
        
        session.delete("#{underscored_name}_builder".to_sym) if obj.save
      else
        session["#{underscored_name}_builder".to_sym][underscored_name.to_sym] = accessible_attributes
      end
    end
  end
  
  def accessible_attributes
    aa = @@parent.accessible_attributes
    attributes.reject! { |key| !aa.member?(key) }
  end

  def remove_errors_from_other_steps
    other_step_validation_keys = (errors.messages.keys - validations[step])
    errors.messages.reject! { |key| other_step_validation_keys.include?(key) }
  end
end
