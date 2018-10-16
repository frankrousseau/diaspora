# frozen_sTring_literal: true

require "spec_helper"

describe Api::V1::LikesController do
  let(:auth) { FactoryGirl.create(:auth_with_read_and_write) }
  let!(:access_token) { auth.create_access_token.to_s }

  before do
    @status = auth.user.post(
      :status_message,
      text:   "This is a status message",
      public: true,
      to:     "all"
    )
  end

  describe "Get Likes for post" do
    context "with right post id" do
      it "succeeds in getting empty likes" do
        get(
          api_v1_post_likes_path(post_id: @status.guid),
          params: {access_token: access_token}
        )
        expect(response.status).to eq(200)
        likes = response_body(response)
        expect(likes.length).to eq(0)
      end

      it "succeeds in getting post with one like" do
        like_service.create(@status.guid)
        get(
          api_v1_post_likes_path(post_id: @status.guid),
          params: {access_token: access_token}
        )
        expect(response.status).to eq(200)
        likes = response_body(response)
        like = likes[0]
        confirm_like_format(like, auth.user)
      end

    end
  end

  describe "#create" do
    context "with right post id" do
      it "succeeeds in liking post" do
        post(
          api_v1_post_likes_path(post_id: @status.guid),
          params: {access_token: access_token}
        )
        expect(response.status).to eq(204)
        likes = like_service.find_for_post(@status.guid)
        expect(likes.length).to eq(1)
        expect(likes[0].author.id).to eq(auth.user.person.id)
      end
    end

    context "with wrong post id" do
      it "fails at liking post" do
        post(
          api_v1_post_likes_path(post_id: 99_999_999),
          params: {access_token: access_token}
        )
        expect(response.status).to eq(404)
      end
    end
  end

  describe "#create" do
    before do
      post(
        api_v1_post_likes_path(post_id: @status.guid),
        params: {access_token: access_token}
      )
    end

    context "with right post id" do
      it "succeeds at unliking post" do
        delete(
          api_v1_post_likes_path(post_id: @status.guid),
          params: {access_token: access_token}
        )
        expect(response.status).to eq(204)
        likes = like_service.find_for_post(@status.guid)
        expect(likes.length).to eq(0)
      end
    end

    context "with wrong post id" do
      it "fails at unliking post" do
        delete(
          api_v1_post_likes_path(post_id: 99_999_999),
          params: {access_token: access_token}
        )
        expect(response.status).to eq(404)
      end
    end
  end

  private

  def confirm_like_format(like, user)
    expect(like.has_key?("guid")).to be_truthy
    author = like["author"]
    expect(author).not_to be_nil
    expect(author["guid"]).to eq(user.guid)
    expect(author["diaspora_id"]).to eq(user.diaspora_handle)
    expect(author["name"]).to eq(user.name)
    expect(author["avatar"]).to eq(user.profile.image_url)
  end

  def like_service
    LikeService.new(auth.user)
  end

  def response_body(response)
    JSON.parse(response.body)
  end

end
