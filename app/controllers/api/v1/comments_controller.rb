# frozen_string_literal: true

module Api
  module V1
    class CommentsController < Api::V1::BaseController
      before_action do
        require_access_token %w[interactions public:read]
      end

      before_action only: %i[create destroy] do
        require_access_token %w[interactions public:modify]
      end

      rescue_from ActiveRecord::RecordNotFound do
        render json: I18n.t("api.endpoint_errors.posts.post_not_found"), status: :not_found
      end

      rescue_from ActiveRecord::RecordInvalid do
        render json: I18n.t("api.endpoint_errors.comments.not_allowed"), status: :unprocessable_entity
      end

      def create
        post = post_service.find!(params[:post_id])
        raise ActiveRecord::RecordNotFound unless post.public? || has_private_modify
        @comment = comment_service.create(params[:post_id], params[:body])
        comment = comment_as_json(@comment)
      rescue ActiveRecord::RecordNotFound
        render json: I18n.t("api.endpoint_errors.posts.post_not_found"), status: :not_found
      else
        render json: comment, status: :created
      end

      def index
        post = post_service.find!(params[:post_id])
        raise ActiveRecord::RecordNotFound unless post.public? || has_private_read
        comments_query = comment_service.find_for_post(params[:post_id])
        params[:after] = Time.utc(1900).iso8601 if params.permit(:before, :after).empty?
        comments_page = time_pager(comments_query).response
        comments_page[:data] = comments_page[:data].map {|x| comment_as_json(x) }
        render json: comments_page
      end

      def destroy
        post = post_service.find!(params[:post_id])
        raise ActiveRecord::RecordInvalid unless post.public? || has_private_modify
        if comment_and_post_validate(params[:post_id], params[:id])
          comment_service.destroy!(params[:id])
          head :no_content
        end
      rescue ActiveRecord::RecordInvalid
        render json: I18n.t("api.endpoint_errors.comments.no_delete"), status: :forbidden
      end

      def report
        post_guid = params.require(:post_id)
        comment_guid = params.require(:comment_id)
        return unless comment_and_post_validate(post_guid, comment_guid)
        reason = params.require(:reason)
        comment = comment_service.find!(comment_guid)
        report = current_user.reports.new(
          item_id:   comment.id,
          item_type: "Comment",
          text:      reason
        )
        if report.save
          head :no_content
        else
          render json: I18n.t("api.endpoint_errors.comments.duplicate_report"), status: :conflict
        end
      end

      private

      def comment_and_post_validate(post_guid, comment_guid)
        if !comment_exists(comment_guid)
          render json: I18n.t("api.endpoint_errors.comments.not_found"), status: :not_found
          false
        elsif !comment_is_for_post(post_guid, comment_guid)
          render json: I18n.t("api.endpoint_errors.comments.not_found"), status: :not_found
          false
        else
          true
        end
      end

      def comment_is_for_post(post_guid, comment_guid)
        comments = comment_service.find_for_post(post_guid)
        comment = comments.find {|comment| comment[:guid] == comment_guid }
        comment ? true : false
      end

      def comment_exists(comment_guid)
        comment = comment_service.find!(comment_guid)
        comment ? true : false
      rescue ActiveRecord::RecordNotFound
        false
      end

      def comment_service
        @comment_service ||= CommentService.new(current_user)
      end

      def post_service
        @post_service ||= PostService.new(current_user)
      end

      def comment_as_json(comment)
        CommentPresenter.new(comment).as_api_response
      end
    end
  end
end
