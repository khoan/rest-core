
require 'rest-core/test'

describe RC::Promise do
  def new_promise
    RC::Promise.new(RC::CLIENT => @client.new)
  end

  before do
    @client  = RC::Builder.client
    @promise = new_promise
  end

  after do
    @client.thread_pool.shutdown
    Muack.verify
  end

  should 'work, reject, yield' do
    @client.pool_size = 1
    flag = 0
    @promise.defer do
      flag.should.eq 0
      flag += 1
      @promise.reject(nil)
    end
    @promise.yield
    flag.should.eq 1
    @promise.send(:error).should.kind_of RC::Error
  end

  should 'work, fulfill, yield' do
    @client.pool_size = 2
    flag = 0
    @promise.defer do
      flag.should.eq 0
      flag += 1
      @promise.fulfill('body', 1, {'K' => 'V'})
    end
    @promise.yield
    flag.should.eq 1
    @promise.send(:body)   .should.eq 'body'
    @promise.send(:status) .should.eq 1
    @promise.send(:headers).should.eq('K' => 'V')
  end

  should 'call inline if pool_size < 0' do
    @client.pool_size = -1
    current_thread = Thread.current
    @promise.defer do
      Thread.current.should.eq current_thread
    end
  end

  should 'call in a new thread if pool_size == 0' do
    @client.pool_size = 0
    thread = nil
    mock(Thread).new.with_any_args.peek_return do |t|
      thread = t
    end
    @promise.defer do
      Thread.current.should.eq thread
      @promise.reject(nil)
    end
    @promise.yield
  end

  should 'call in thread pool if pool_size > 0' do
    @client.pool_size = 1
    flag = 0
    rd, wr = IO.pipe
    @promise.defer do
      rd.gets
      flag.should.eq 0
      flag += 1
      @promise.reject(nil)
    end
    p1 = new_promise
    p1.defer do # block until promise #0 is done because pool_size == 1
      flag.should.eq 1
      flag += 1
      p1.reject(nil)
    end
    wr.puts  # start promise #0
    @promise.yield
    p1.yield # block until promise #1 is done
    flag.should.eq 2
  end
end