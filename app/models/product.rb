class Product < ActiveRecord::Base
  attr_accessible :category, :name, :price

  validates_presence_of :category, :name, :price
end
