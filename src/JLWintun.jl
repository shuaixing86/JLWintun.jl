"""
ROOT permission is required to run!!!
# Define:
    WINTUN_MAX_POOL 256
    WINTUN_MIN_RING_CAPACITY 0x20000 /* 128kiB */
    WINTUN_MAX_RING_CAPACITY 0x4000000 /* 64MiB */
    WINTUN_MAX_IP_PACKET_SIZE 0xFFFF
# Doc:
    https://github.com/shuaixing86/Wintun
    https://www.wintun.net/
"""
module JLWintun

# loading dll file
arch = Sys.ARCH
if arch == :x86_64 || arch == :amd64
    dll_path = "wintun_amd64.dll"
elseif arch == :arm64 || aarch64 
    dll_path = "wintun_arm64.dll"
elseif arch == :x86
    dll_path = "wintun_x86.dll"
elseif arch == :arm
    dll_path = "wintun_arm.dll"
else
    error("Please use 'Sys.ARCH' to view your current system number and modify the first few lines of the 'Wintun. jl' file in this package")
end
const wintunpath = joinpath(@__DIR__, dll_path)

"""
Creates a new Wintun adapter.

Parameters

Name: The requested name of the adapter. Zero-terminated string of up to MAX_ADAPTER_NAME-1 characters.
Name: Name of the adapter tunnel type. Zero-terminated string of up to MAX_ADAPTER_NAME-1 characters.
RequestedGUID: The GUID of the created network adapter, which then influences NLA generation deterministically. If it is set to NULL, the GUID is chosen by the system at random, and hence a new NLA entry is created for each new adapter. It is called "requested" GUID because the API it uses is completely undocumented, and so there could be minor interesting complications with its usage.
Returns

If the function succeeds, the return value is the adapter handle. Must be released with WintunCloseAdapter. If the function fails, the return value is NULL. To get extended error information, call GetLastError.
"""
function WintunCreateAdapter(name::String, type::String, guid::String)
    adapter = ccall((:WintunCreateAdapter, wintunpath), Ptr{Cvoid}, (Cwstring, Cwstring, Cwstring), name, type, guid)
    if adapter == Ptr{Nothing}
        error("Failed to create adapter")
    end
    return adapter
end

"""
Opens an existing Wintun adapter.

Parameters

Name: The requested name of the adapter. Zero-terminated string of up to MAX_ADAPTER_NAME-1 characters.
Returns

If the function succeeds, the return value is adapter handle. Must be released with WintunCloseAdapter. If the function fails, the return value is NULL. To get extended error information, call GetLastError.
"""
function WintunOpenAdapter(name::String)
    adapter = ccall((:WintunOpenAdapter, wintunpath), Ptr{Cvoid}, (Cwstring,), name)
    if adapter == Ptr{Nothing}
        error("Failed to open adapter")
    end
    return adapter
end

"""
Releases Wintun adapter resources and, if adapter was created with WintunCreateAdapter, removes adapter.

Parameters

Adapter: Adapter handle obtained with WintunCreateAdapter or WintunOpenAdapter.
"""
function WintunCloseAdapter(adapter::Ptr{Cvoid})
    ccall((:WintunCloseAdapter, wintunpath), Cvoid, (Ptr{Cvoid},), adapter)
end

"""
Deletes the Wintun driver if there are no more adapters in use.

Returns

If the function succeeds, the return value is nonzero. If the function fails, the return value is zero. To get extended error information, call GetLastError.
"""
function WintunDeleteDriver()
    return ccall((:WintunDeleteDriver, wintunpath), Cint, ())
end

"""
Returns the LUID of the adapter.

Parameters

Adapter: Adapter handle obtained with WintunOpenAdapter or WintunCreateAdapter
Luid: Pointer to LUID to receive adapter LUID.
"""
function WintunGetAdapterLuid(adapter::Ptr{Cvoid}, luid::Ptr{Cvoid})
    ccall((:WintunGetAdapterLuid, wintunpath), Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}), adapter, luid)
end

"""
Determines the version of the Wintun driver currently loaded.

Returns

If the function succeeds, the return value is the version number. If the function fails, the return value is zero. To get extended error information, call GetLastError. Possible errors include the following: ERROR_FILE_NOT_FOUND Wintun not loaded
"""
function WintunGetRunningDriverVersion()
    return ccall((:WintunGetRunningDriverVersion, wintunpath), UInt32, ())
end

"""
Sets logger callback function.

Parameters

NewLogger: Pointer to callback function to use as a new global logger. NewLogger may be called from various threads concurrently. Should the logging require serialization, you must handle serialization in NewLogger. Set to NULL to disable.
"""
function WintunSetLogger(new_logger::Ptr{Cvoid})
    ccall((:WintunSetLogger, wintunpath), Cvoid, (Ptr{Cvoid},), new_logger)
end

"""
Starts Wintun session.

Parameters

Adapter: Adapter handle obtained with WintunOpenAdapter or WintunCreateAdapter
Capacity: Rings capacity. Must be between WINTUN_MIN_RING_CAPACITY and WINTUN_MAX_RING_CAPACITY (incl.) Must be a power of two.
Returns

Wintun session handle. Must be released with WintunEndSession. If the function fails, the return value is NULL. To get extended error information, call GetLastError.
"""
function WintunStartSession(adapter::Ptr{Cvoid}, capacity::UInt32)
    session = ccall((:WintunStartSession, wintunpath), Ptr{Cvoid}, (Ptr{Cvoid}, UInt32), adapter, capacity)
    if session == Ptr{Nothing}
        error("Failed to start session")
    end
    return session
end

"""
Ends Wintun session.

Parameters

Session: Wintun session handle obtained with WintunStartSession
"""
function WintunEndSession(session::Ptr{Cvoid})
    ccall((:WintunEndSession, wintunpath), Cvoid, (Ptr{Cvoid},), session)
end

"""
Gets Wintun session's read-wait event handle.

Parameters

Session: Wintun session handle obtained with WintunStartSession
Returns

Pointer to receive event handle to wait for available data when reading. Should WintunReceivePackets return ERROR_NO_MORE_ITEMS (after spinning on it for a while under heavy load), wait for this event to become signaled before retrying WintunReceivePackets. Do not call CloseHandle on this event - it is managed by the session.
"""
function WintunGetReadWaitEvent(session::Ptr{Cvoid})
    return ccall((:WintunGetReadWaitEvent, wintunpath), Ptr{Cvoid}, (Ptr{Cvoid},), session)
end

"""
Retrieves one or packet. After the packet content is consumed, call WintunReleaseReceivePacket with Packet returned from this function to release internal buffer. This function is thread-safe.

Parameters

Session: Wintun session handle obtained with WintunStartSession
PacketSize: Pointer to receive packet size.
Returns

Pointer to layer 3 IPv4 or IPv6 packet. Client may modify its content at will. If the function fails, the return value is NULL. To get extended error information, call GetLastError. Possible errors include the following: ERROR_HANDLE_EOF Wintun adapter is terminating; ERROR_NO_MORE_ITEMS Wintun buffer is exhausted; ERROR_INVALID_DATA Wintun buffer is corrupt
"""
function WintunReceivePacket(session::Ptr{Cvoid}, packet_size::Ptr{UInt32})
    return ccall((:WintunReceivePacket, wintunpath), Ptr{UInt8}, (Ptr{Cvoid}, Ptr{UInt32}), session, packet_size)
end

"""
Releases internal buffer after the received packet has been processed by the client. This function is thread-safe.

Parameters

Session: Wintun session handle obtained with WintunStartSession
Packet: Packet obtained with WintunReceivePacket
"""
function WintunReleaseReceivePacket(session::Ptr{Cvoid}, packet::Ptr{UInt8})
    ccall((:WintunReleaseReceivePacket, wintunpath), Cvoid, (Ptr{Cvoid}, Ptr{UInt8}), session, packet)
end

"""
Allocates memory for a packet to send. After the memory is filled with packet data, call WintunSendPacket to send and release internal buffer. WintunAllocateSendPacket is thread-safe and the WintunAllocateSendPacket order of calls define the packet sending order.

Parameters

Session: Wintun session handle obtained with WintunStartSession
PacketSize: Exact packet size. Must be less or equal to WINTUN_MAX_IP_PACKET_SIZE.
Returns

Returns pointer to memory where to prepare layer 3 IPv4 or IPv6 packet for sending. If the function fails, the return value is NULL. To get extended error information, call GetLastError. Possible errors include the following: ERROR_HANDLE_EOF Wintun adapter is terminating; ERROR_BUFFER_OVERFLOW Wintun buffer is full;
"""
function WintunAllocateSendPacket(session::Ptr{Cvoid}, packet_size::UInt32)
    return ccall((:WintunAllocateSendPacket, wintunpath), Ptr{UInt8}, (Ptr{Cvoid}, UInt32), session, packet_size)
end

"""
Sends the packet and releases internal buffer. WintunSendPacket is thread-safe, but the WintunAllocateSendPacket order of calls define the packet sending order. This means the packet is not guaranteed to be sent in the WintunSendPacket yet.

Parameters

Session: Wintun session handle obtained with WintunStartSession
Packet: Packet obtained with WintunAllocateSendPacket
"""
function WintunSendPacket(session::Ptr{Cvoid}, packet::Ptr{UInt8})
    ccall((:WintunSendPacket, wintunpath), Cvoid, (Ptr{Cvoid}, Ptr{UInt8}), session, packet)
end

end # module JLWintun
