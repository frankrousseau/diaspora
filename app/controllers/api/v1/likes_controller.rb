# frozen_string_literal: true

module Api
  module V1
    class LikesController < Api::V1::BaseController
      before_action only: %i[create destroy] do
        require_access_token %w[write]
      end

      rescue_from ActiveRecord::RecordNotFound do
        render json: I18n.t("likes.not_found"), status: :not_found
      end

      rescue_from ActiveRecord::RecordInvalid do
        render json: I18n.t("likes.create.fail"), status: :not_found
      end

      def show
        likes = like_service.find_for_post(params[:post_id])
        render json: likes.map {|x| like_json(x) }
      end

      def create
        like_service.create(params[:post_id])
        head :no_content, status: 204
      end

      def destroy
        like_service.unlike_post(params[:post_id])
        head :no_content, status: 204
      end

      def like_service
        @like_service ||= LikeService.new(current_user)
      end

      private

      def like_json(like)
        LikesPresenter.new(like).as_api_json
      end
    end
  end
end
