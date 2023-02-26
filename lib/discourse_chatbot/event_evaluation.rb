module ::DiscourseChatbot

  class EventEvaluation

    # DELAY_IN_SECONDS = 3

    def on_submission(submission)
      raise "Overwrite me!"
    end

    private

    def invoke_background_job(job_class, opts)
      delay_in_seconds = DELAY_IN_SECONDS.to_i
      if delay_in_seconds > 0
        job_class.perform_in(delay_in_seconds.seconds, opts.as_json)
      else
        job_class.perform_async(opts.as_json)
      end
    end

  end
end
