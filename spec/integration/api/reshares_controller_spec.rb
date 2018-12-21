# frozen_sTring_literal: true

require "spec_helper"

describe Api::V1::ResharesController do
  let(:auth) {
    FactoryGirl.create(:auth_with_all_scopes)
  }

  let(:auth_read_only) {
    FactoryGirl.create(:auth_with_read_scopes)
  }

  let(:auth_profile_only) {
    FactoryGirl.create(:auth_with_default_scopes)
  }

  let!(:access_token) { auth.create_access_token.to_s }
  let!(:access_token_read_only) { auth_read_only.create_access_token.to_s }
  let!(:access_token_profile_only) { auth_profile_only.create_access_token.to_s }

  before do
    @user_post = auth.user.post(
      :status_message,
      text:   "This is a status message",
      public: true,
      to:     "all"
    )

    @eve_post = eve.post(
      :status_message,
      text:   "This is Bob's status message",
      public: true,
      to:     "all"
    )

    @alice_reshare = ReshareService.new(alice).create(@user_post.id)
  end

  describe "#show" do
    context "with valid post id" do
      it "succeeds" do
        get(
          api_v1_post_reshares_path(@user_post.guid),
          params: {access_token: access_token}
        )

        expect(response.status).to eq(200)
        reshares = response_body_data(response)
        expect(reshares.length).to eq(1)
        reshare = reshares[0]
        expect(reshare["guid"]).not_to be_nil
        confirm_person_format(reshare["author"], alice)
      end

      it "succeeds but empty with private post it can see" do
        private_post = auth.user.post(
          :status_message,
          text:   "to aspect only",
          public: false,
          to:     auth.user.aspects.first.id
        )

        get(
          api_v1_post_reshares_path(private_post.id),
          params: {
            access_token: access_token
          }
        )
        expect(response.status).to eq(200)
        reshares = response_body_data(response)
        expect(reshares.length).to eq(0)
      end
    end

    context "with invalid post id" do
      it "fails with bad id" do
        get(
          api_v1_post_reshares_path("999_999_999"),
          params: {access_token: access_token}
        )

        expect(response.status).to eq(404)
        expect(response.body).to eq(I18n.t("api.endpoint_errors.posts.post_not_found"))
      end

      it "fails with private post it shouldn't see" do
        private_post = alice.post(:status_message, text: "to aspect only", public: false, to: alice.aspects.first.id)
        get(
          api_v1_post_reshares_path(private_post.id),
          params: {
            access_token: access_token
          }
        )
        expect(response.status).to eq(404)
        expect(response.body).to eq(I18n.t("api.endpoint_errors.posts.post_not_found"))
      end
    end

    context "improper credentials" do
      it "fails when not logged in" do
        get(
          api_v1_post_reshares_path(@user_post.id),
          params: {
            access_token: "999_999_999"
          }
        )
        expect(response.status).to eq(401)
      end
    end
  end

  describe "#create" do
    context "with valid post id" do
      it "succeeds" do
        post(
          api_v1_post_reshares_path(post_id: @eve_post.guid),
          params: {access_token: access_token}
        )

        expect(response.status).to eq(200)
        post = JSON.parse(response.body)
        expect(post["guid"]).not_to be_nil
        expect(post["body"]).to eq(@eve_post.text)
        expect(post["post_type"]).to eq("Reshare")
        expect(post["author"]["guid"]).to eq(auth.user.guid)
        expect(post["root"]["guid"]).to eq(@eve_post.guid)
      end

      it "fails to reshare twice" do
        reshare_service.create(@eve_post.id)
        post(
          api_v1_post_reshares_path(post_id: @eve_post.guid),
          params: {access_token: access_token}
        )

        expect(response.status).to eq(422)
        expect(response.body).to eq(I18n.t("reshares.create.error"))
      end
    end

    context "with invalid post id" do
      it "fails with bad id" do
        post(
          api_v1_post_reshares_path(post_id: "999_999_999"),
          params: {access_token: access_token}
        )

        expect(response.status).to eq(422)
        expect(response.body).to eq(I18n.t("reshares.create.error"))
      end

      it "fails with own post" do
        post(
          api_v1_post_reshares_path(post_id: @user_post.guid),
          params: {access_token: access_token}
        )

        expect(response.status).to eq(422)
        expect(response.body).to eq(I18n.t("reshares.create.error"))
      end

      it "fails with private post it shouldn't see" do
        private_post = alice.post(:status_message, text: "to aspect only", public: false, to: alice.aspects.first.id)
        post(
          api_v1_post_reshares_path(private_post.id),
          params: {
            access_token: access_token
          }
        )
        expect(response.status).to eq(422)
        expect(response.body).to eq(I18n.t("reshares.create.error"))
      end

      it "fails with private post it can see" do
        private_post = alice.post(:status_message, text: "to aspect only", public: false, to: alice.aspects)
        get(
          api_v1_post_reshares_path(private_post.id),
          params: {
            access_token: access_token
          }
        )
        expect(response.status).to eq(404)
        expect(response.body).to eq(I18n.t("api.endpoint_errors.posts.post_not_found"))
      end
    end

    context "improper credentials" do
      it "fails when not logged in" do
        post(
          api_v1_post_reshares_path(@eve_post.id),
          params: {
            access_token: "999_999_999"
          }
        )
        expect(response.status).to eq(401)
      end

      it "fails when logged in read only" do
        post(
          api_v1_post_reshares_path(@eve_post.id),
          params: {
            access_token: auth_read_only
          }
        )
        expect(response.status).to eq(401)
      end
    end
  end

  private

  def reshare_service(user=auth.user)
    @reshare_service ||= ReshareService.new(user)
  end

  def response_body_data(response)
    JSON.parse(response.body)["data"]
  end

  # rubocop:disable Metrics/AbcSize
  def confirm_person_format(post_person, user)
    expect(post_person["guid"]).to eq(user.guid)
    expect(post_person["diaspora_id"]).to eq(user.diaspora_handle)
    expect(post_person["name"]).to eq(user.name)
    expect(post_person["avatar"]).to eq(user.profile.image_url)
  end
  # rubocop:enable Metrics/AbcSize
end
