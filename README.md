Recently I stumbled across a great gem, [Wicked Wizard](https://github.com/schneems/wicked). As I dug in further I noticed they had a great guide for [building partial objects step by step](https://github.com/schneems/wicked/wiki/Building-Partial-Objects-Step-by-Step). However, it didn't seem to do quite what I wanted. I was looking for something that:

1. <span>Doesn't require the model have knowledge of the wizard in order to perform validations.</span>
2. <span>Doesn't require me to clean up incomplete objects when someone didn't go through the whole wizard.</span>

I decided to start tackling requirement 2 first, since I had an idea how to go about that. I figured if I stored objects in the session, I could just keep building it there until it came time for the final submission. I googled for a solution and the closest thing I could find was [this gist](https://gist.github.com/kizzx2/4722784) about using the session to store a partial object. When I tried to use it though, it didn't work for me. Based on the gist though, I was able to come up with a solution which I'll detail below. I'll use the same example as the Wicked Wizard guide (a product).

First, let's create our product class:

    class Product < ActiveRecord::Base
      attr_accessible :category, :name, :price

      validates_presence_of :category, :name, :price
    end


Next, let's begin creating our controller. Starting from what Wicked Wizard tells us to do, we'd have something like this:

    class ProductWizardController < ApplicationController
      include Wicked::Wizard

      steps :add_name, :add_price, :add_category

      def show
        @product = Product.find(params[:product_id])
        render_wizard
      end

      def update
        @product = Product.find(params[:product_id])
        @product.update_attributes(params[:product])
        render_wizard @product
      end

      def create
        @product = Product.create
        redirect_to wizard_path(steps.first, :product_id => @product.id)
      end
    end

But the `Product.find(params[:product_id])` and `Product.create` lines aren't going to work for us anymore. In fact, it doesn't make sense to have a create action at all, since we don't create a product to start. So let's remove the create action and put a new action in it's place:

    def new
      product = WizardProduct.new

      session[:product_wizard] ||= {}
      session[:product_wizard][:product] = product.accessible_attributes

      redirect_to wizard_path(steps.first)
    end

You haven't seen the WizardProduct class yet, but we'll get to that in a minute. What we've done is instantiated a new product, stored any data that product has in the session, and then redirected to step one of our wizard, `:add_name`. As I mentioned earlier, we can't use `Product.find` anymore, so let's change our show action to the following:

    def show
      @product = WizardProduct.new(session[:product_wizard][:product])
      @step = step

      render_wizard
    end

Instead of going and finding our object like we would with a database, we're going to instantiate a new one each time with the attributes we've stored in the session. Initially I tried storing the whole object in the session but due to limitations on how much you can store there this would consistently fail.

Next, we'll also need to remove `Product.find` in the update action:

    def update
      @product = WizardProduct.new(session[:product_wizard][:product])
      @product.attributes = params[:product]

      @product.step = step
      @product.steps = steps
      @product.session = session
      @product.validations = validations

      render_wizard @product
    end

Now things are getting a bit more complicated and it's time to discuss the WizardProduct class. What we've done so far is to instantiate our WizardProduct object with the attributes stored in the session, and we've added a bunch of data to it that our WizardProduct class will need to do it's job. Let's take a look at WizardProduct:

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

OK. What does this do? Well we've got some accessors for the step we're currently on, a list of all the steps, the session itself, and validations we need to perform. Then we store the parent class as a class variable, and get some helper methods related to the parent class that we'll need later.

A key part of this is rewriting the save method. Here, we check if the object is valid, and then remove all the errors we don't care about. Finally, we check if there are no errors. If not, but we're not at the last step yet, we store the attributes of the object in the session. The controller takes care of moving to the next step. If we're at the last step, we instantiate a new instance of the parent model with the attributes we retrieved from the session, and save it. And there you have it! 

### Limitations

There are a couple limitations with the way I'm currently doing things.

1. <span>All attributes must be mass-assignable. This is how I can do `@@parent.new(accessible_attributes)`. There are ways around this, but it makes sense, since you are assigning these attributes through the interface. I'm working on an updated version for Rails 4 that will use strong params instead.</span>
2. <span>Assocations don't work at all. If you accept nested attributes for things, this just flat out won't work. It is fairly easy to make it work on a case by case basis, but I haven't figured out a generalized solution yet. I'm happy to hear suggestions!</span>

If you have ways you think these limitations could be overcome, or you think I could do certain things better, feel free to get in touch with [me on Twitter](http://twitter.com/eroberts).

### Help

Please help! Accepting pull requests, praise, criticism, and thinly veiled hatred.

### Final notes
You can find the project on GitHub at [github.com/ericroberts/wizard-object](https://github.com/ericroberts/wizard-object)

By the way, here's the full controller with all the changes we made:

    class ProductWizardController < ApplicationController
      include Wicked::Wizard

      steps :add_name, :add_price, :add_category

      def new
        product = WizardProduct.new

        session[:product_wizard] ||= {}
        session[:product_wizard][:product] = product.accessible_attributes

        redirect_to wizard_path(steps.first)
      end

      def show
        @pick = WizardProduct.new(session[:product_wizard][:product])
        @step = step

        render_wizard
      end

      def update
        @product = WizardProduct.new(session[:product_wizard][:product])
        @product.attributes = params[:product]

        @product.step = step
        @product.steps = steps
        @product.session = session
        @product.validations = validations

        render_wizard @product
      end

      def finish_wizard_path
        products_path
      end

      def validations
        {
          add_name: [:name],
          add_price: [:price],
          add_category: [:category]
        }
      end
    end
