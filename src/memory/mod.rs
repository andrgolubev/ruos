pub use self::area_frame_allocator::AreaFrameAllocator;
mod area_frame_allocator;

#[derive(Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct Frame {
    number: usize
}

pub const PAGE_SIZE: usize = 4096;

impl Frame {
    fn from_address(addr: usize) -> Frame {
        return Frame{ number: addr / PAGE_SIZE };
    }
}

pub trait FrameAllocator {
    fn allocate_frame(&mut self) -> Option<Frame>;
    fn deallocate_frame(&mut self) -> Option<Frame>;
}
