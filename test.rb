require "aws/s3"

AWS::S3::Base.establish_connection!(
  :access_key_id     => "AKIAJM6UM7QJIER6VHZA",
  :secret_access_key => "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"
)

puts AWS::S3::Bucket.find("pdfer")
file = AWS::S3::S3Object.store('e7af22e691a678c8985960a5ffc0cac7_1.png', open('/Users/matt/Sites/syllabuster/pdfer/jobs/e7af22e691a678c8985960a5ffc0cac7/images/large/e7af22e691a678c8985960a5ffc0cac7_1.png'), 'pdfer')

puts file.inspect