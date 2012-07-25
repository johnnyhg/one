# -*- encoding: utf-8 -*-

class Order # 訂單
  include Mongoid::Document
  # Embedded
  embedded_in :trade
  
  # Fieldstype:
  field :cid,                 type: Integer
  field :num,                 type: Integer
  field :num_iid,             type: Integer
  field :oid,                 type: Integer
  field :refund_id,           type: Integer
  field :refund_num,          type: Integer, default: 0
  
  field :refund_fee,          type: Float, default: 0
  field :adjust_fee,          type: Float
  field :discount_fee,        type: Float
  field :payment,             type: Float
  field :price,               type: Float
  field :total_fee,           type: Float
  
  field :outer_iid,           type: String
  field :outer_sku_id,        type: String
  field :pic_path,            type: String
  field :refund_status,       type: String
  field :sku_id,              type: String
  field :sku_properties_name, type: String
  field :status,              type: String
  field :title,               type: String
  field :snapshot_url,        type: String
  
  field :is_oversold,         type: Boolean, default: false
  field :buyer_rate,          type: Boolean, default: false
  field :seller_rate,         type: Boolean, default: false
  
  key :oid
  
  def price_total
    ( price.to_f / num.to_f ).round(2)
  end

  def discount_rate
    (discount_fee.to_f / price_total.to_f * 100).round.to_s + '%'
  end

  def payment_rate
    ( payment.to_f / price_total.to_f * 100).round.to_s + '%'
  end
  
  def total_avg
    ( total_fee.to_f / num.to_f ).round(2)
  end
  
  def payment_avg
    ( payment.to_f / num.to_f ).round(2)
  end
  
end