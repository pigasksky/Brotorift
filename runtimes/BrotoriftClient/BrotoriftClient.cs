﻿using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Sockets;
using System.Text;
using System.Threading;

namespace Brotorift
{
	public abstract class Client
	{
		private TcpClient _client;

		private Thread _recvThread;

		private MemoryStream _recvBuffer;

		private NetworkStream _stream;

		private int _segmentSize;

		private Queue<Packet> _packetsToReceive;

		private Queue<Packet> _packetsToSend;

		private Mutex _receivePacketsLock;

		public Client( int segmentSize )
		{
			_client = new TcpClient();
			_recvThread = new Thread( this.ReceiveLoop );
			_recvBuffer = new MemoryStream();
			_segmentSize = segmentSize;
			_packetsToReceive = new Queue<Packet>();
			_packetsToSend = new Queue<Packet>();
			_receivePacketsLock = new Mutex();
		}

		public void Connect( string hostname, int port )
		{
			_client.Connect( hostname, port );
			_stream = _client.GetStream();
			_recvThread.Start();
		}

		public IAsyncResult BeginConnect( string hostname, int port, AsyncCallback callback, object state )
		{
			return _client.BeginConnect( hostname, port, callback, state );
		}

		public void EndConnect( IAsyncResult asyncResult )
		{
			_client.EndConnect( asyncResult );
			_stream = _client.GetStream();
			_recvThread.Start();
		}

		public bool Update()
		{
			_receivePacketsLock.WaitOne();
			while( _packetsToReceive.Count > 0 )
			{
				var packet = _packetsToReceive.Dequeue();
				if( packet == null )
				{
					return false;
				}
				this.ProcessPacket( packet );
			}
			_receivePacketsLock.ReleaseMutex();

			while( _packetsToSend.Count > 0 )
			{
				var packet = _packetsToSend.Dequeue();
				var result = this.DoSendPacket( packet );
				if( result == false )
				{
					return false;
				}
			}

			return true;
		}

		private void ReceiveLoop()
		{
			try
			{
				for( ; ; )
				{
					var segment = new byte[_segmentSize];
					var bytesRead = _stream.Read( segment, 0, _segmentSize );
					if( bytesRead > 0 )
					{
						var currentPosition = 0;
						_recvBuffer.Write( segment, currentPosition, bytesRead );
						currentPosition += bytesRead;
						while( bytesRead == _segmentSize && _stream.DataAvailable )
						{
							bytesRead = _stream.Read( segment, 0, _segmentSize );
							_recvBuffer.Write( segment, currentPosition, bytesRead );
							currentPosition += bytesRead;
						}
					}
					this.PushPackets();
				}
			}
			catch( IOException )
			{
				_receivePacketsLock.WaitOne();
				_packetsToReceive.Enqueue( null );
				_receivePacketsLock.ReleaseMutex();
			}
		}

		private void PushPackets()
		{
			while( _recvBuffer.Length > sizeof( int ) )
			{
				var reader = new BinaryReader( _recvBuffer );
				var packetSize = reader.ReadInt32();
				if( _recvBuffer.Length - _recvBuffer.Position < packetSize )
				{
					_recvBuffer.Position -= sizeof( int );
					break;
				}

				var content = reader.ReadBytes( packetSize );
				_receivePacketsLock.WaitOne();
				_packetsToReceive.Enqueue( new Packet( content ) );
				_receivePacketsLock.ReleaseMutex();
			}

			if( _recvBuffer.Position > 0 )
			{
				var newBuffer = new MemoryStream( _recvBuffer.GetBuffer(), (int)_recvBuffer.Position, (int)( _recvBuffer.Length - _recvBuffer.Position ) );
				_recvBuffer = newBuffer;
			}
		}

		protected void SendPacket( Packet packet )
		{
			_packetsToSend.Enqueue( packet );
		}

		private bool DoSendPacket( Packet packet )
		{
			var stream = new MemoryStream();
			var writer = new BinaryWriter( stream );
			writer.Write( packet.Length );
			writer.Write( packet.Buffer, 0, packet.Length );

			try
			{
				_stream.Write( stream.GetBuffer(), 0, (int)stream.Length );
			}
			catch( IOException )
			{
				return false;
			}

			return true;
		}

		protected abstract void ProcessPacket( Packet packet );
	}
}
