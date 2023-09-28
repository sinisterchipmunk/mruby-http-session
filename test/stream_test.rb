assert 'OutputStream#write appends to end of buffer' do
  outstream = HTTP::Session::OutputStream.new
  outstream.write('1')
  outstream.write('2')
  assert_equal '1', outstream.read(1)
  assert_equal '2', outstream.read(1)
end

assert 'Stream#read can return less than n bytes, #read_exacty can not' do
  bytes = "1234".chars
  stream = HTTP::Session::Stream.new { bytes.shift }
  assert_equal '1', stream.read(4)
  assert_equal '234', stream.read_exactly(3)
  bytes = '1234'.chars
  assert_equal '1234', stream.read_exactly(100) # except on EOF
end

assert 'Stream#read prioritizes buffer data and returns without a recv if there is buffer data' do
  bytes = "1234".chars
  stream = HTTP::Session::Stream.new('bufferdata') { bytes.shift }
  assert_equal 'bufferdata', stream.read(100)
end
