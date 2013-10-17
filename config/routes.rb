WizardObject32::Application.routes.draw do
  resources :product_wizard
  resources :products

  root to: 'product_wizard#new'
end
