Spree::User.class_eval do
  include Spree::TransactionRegistrable
  attr_accessor :referral_code, :affiliate_code, :can_activate_associated_partner

  has_one :referral
  has_one :referred_record
  has_one :affiliate, through: :referred_record, foreign_key: :affiliate_id
  has_one :affiliate_record, class_name: 'Spree::ReferredRecord'
  has_many :transactions, as: :commissionable, class_name: 'Spree::CommissionTransaction', dependent: :restrict_with_error

  after_create :create_referral
  after_create :referral_affiliate_check
  after_update :activate_associated_partner, if: :associated_partner_activable?

  def referred_by
    referred_record.try(:referral).try(:user)
  end

  def referred_count
    referral.referred_records.count
  end

  def referred?
    !referred_record.try(:referral).try(:user).nil?
  end

  def affiliate?
    !affiliate.nil?
  end

  def associated_partner
    @associated_partner ||= Spree::Affiliate.find_by(email: email)
  end

  def associated_partner?
    !associated_partner.nil?
  end

  protected
    def password_required?
      if new_record? && spree_roles.include?(Spree::Role.affiliate)
        false
      else
        super
      end
    end

  private
    def referral_affiliate_check
      if referral_code.present?
        referred = Spree::Referral.find_by(code: referral_code)
      elsif affiliate_code.present?
        referred = Spree::Affiliate.find_by(path: affiliate_code)
        register_commission_transaction(referred) if referred
      end
      if referred
        referred.referred_records.create(user: self)
      end
    end

    def activate_associated_partner
      associated_partner.update_attributes(activation_token: nil, activated_at: Time.current, active: true)
    end

    def associated_partner_activable?
      can_activate_associated_partner && associated_partner? && !associated_partner.active?
    end
end
