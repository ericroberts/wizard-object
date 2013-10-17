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
    @product = WizardProduct.new(session[:product_wizard].try(:[], [:product]))
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
