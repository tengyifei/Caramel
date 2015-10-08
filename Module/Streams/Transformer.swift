//
//  Transforming.swift
//  Caramel
//
//  Created by Steve Streza on 4.10.15.
//  Copyright © 2015 Lunar Guard. All rights reserved.
//

public protocol Transforming {
	typealias Input: StreamBuffer
	typealias Output: StreamBuffer
	
	func start()
	func transform(input: Input) throws -> Output
	func finish() throws -> Output?
}

public class Transformer<T, U where T: StreamBuffer, U: StreamBuffer> : Transforming {
	public typealias Input = T
	public typealias Output = U
	
	public func start() {
		
	}
	
	public func transform(input: Input) throws -> Output {
		return Output()
	}
	
	public func finish() throws -> Output? {
		return nil
	}
}

public final class BlockTransformer<T, U where T: StreamBuffer, U: StreamBuffer>: Transformer<T, U> {
	public typealias TransformBlock = (T, BlockTransformer) throws -> U
	
	public let transformer: TransformBlock
	
	public init(transformer: TransformBlock) {
		self.transformer = transformer
	}

}

public class TransformingPullStream<T, U where U: StreamBuffer, T: Pullable>: TransformPullable {
	public typealias InputStream = T
	public typealias Sequence = U
	public typealias Output = U
	
	let transformer: Transformer<InputStream.Sequence, Sequence>
	
	public var pullStream: InputStream
	
	public var inputBuffer: InputStream.Sequence
	public var buffer: Sequence
	
	public init(inputStream: InputStream, transformer: Transformer<InputStream.Sequence, Sequence>) {
		self.pullStream = inputStream

		self.inputBuffer = InputStream.Sequence()
		self.buffer = Sequence()
		
		self.transformer = transformer
	}
	
	public func pull() -> Sequence? {
		if let input = self.pullStream.pull() {
			let output = try! self.transformer.transform(input)
			return output
		} else {
			fatalError()
		}
	}
	
	public var isAtEnd: Bool {
		return self.pullStream.isAtEnd
	}
}

public class TransformingPushStream<T, U where T: Pushable, U: StreamBuffer>: PushStream<U>, TransformPushable {
	public typealias InputStream = T
	public typealias Output = U
	public typealias PushHandler = (Result<Sequence>) -> Void
	
	let transformer: Transformer<InputStream.Sequence, Sequence>
	
	public var pushStream: InputStream
	
	public var inputBuffer: InputStream.Sequence
	
	public init(inputStream: InputStream, transformer: Transformer<InputStream.Sequence, Sequence>) {
		self.pushStream = inputStream
		self.inputBuffer = InputStream.Sequence()
		self.transformer = transformer
		super.init()

		self.pushStream.wait(({ (result: Result<InputStream.Sequence>) -> Void in
			do {
				let inValue = try result.result()
				let outValue = try self.transformer.transform(inValue)
				self.write(outValue)
			} catch let error {
				self.writeError(error)
			}
		}) as! InputStream.PushHandler)
	}
	
	public override var isAtEnd: Bool {
		return self.pushStream.isAtEnd
	}
}

public extension Pullable {
	func transformWith<T: StreamBuffer>(transformer: Transformer<Sequence, T>) -> TransformingPullStream<Self, T> {
		return TransformingPullStream(inputStream: self, transformer: transformer)
	}
	func transform<T: StreamBuffer>(block: (Self.Sequence) throws -> T) -> TransformingPullStream<Self, T> {
		return transformWith(BlockTransformer(transformer: { (sequence: Sequence, _: BlockTransformer<Sequence, T>) throws -> T in
			return try block(sequence)
		}))
	}
}

public extension Pushable {
	func transformWith<T: StreamBuffer>(transformer: Transformer<Sequence, T>) -> TransformingPushStream<Self, T> {
		return TransformingPushStream(inputStream: self, transformer: transformer)
	}
	func transform<T: StreamBuffer>(block: (Sequence) throws -> T) -> TransformingPushStream<Self, T> {
		return transformWith(BlockTransformer(transformer: { (sequence: Sequence, _: BlockTransformer<Sequence, T>) throws -> T in
			return try block(sequence)
		}))
	}
}