#import <Foundation/Foundation.h>

namespace AIFF {
		
	#define DESKTOP_PATH(v) [NSString stringWithFormat:@"%@/%@",[NSSearchPathForDirectoriesInDomains(NSDesktopDirectory,NSUserDomainMask,YES) objectAtIndex:0],v]

	typedef struct {
		double *data;
		long length;
	} Buffer;

	void dump(unsigned char *ptr) {
		printf("%c",*ptr++);
		printf("%c",*ptr++);
		printf("%c",*ptr++);
		printf("%c\n",*ptr);
	}
	
	static unsigned short to(double f){
		short tmp = (32767*f);		
		return (unsigned char)(tmp>>8)|(((unsigned char)(tmp&0xFF))<<8);
	}
	
	static double from(unsigned char *p) {
		return ((short)((p[0]<<8)|p[1]))/32767.; 
	}
	

	static unsigned int *swap(unsigned int *p) {
		*p = ((*p)<<24)|(((*p)<<8)&0xFF0000)|(((*p)>>8)&0xFF00)|((*p)>>24);
		return p;
	}

	static unsigned short *swap(unsigned short *p) {
		*p = (((*p)<<8)&0xFF00)|((*p)>>8);
		return p;
	}

	static unsigned short swap(unsigned short p) { 
		return (((p)<<8)&0xFF00)|((p)>>8); 
	}

	static unsigned int swap(unsigned int p) { 
		return ((p)<<24)|(((p)<<8)&0xFF0000)|(((p)>>8)&0xFF00)|((p)>>24); 
	}

	static unsigned short pack(unsigned char a,unsigned char b) {
		return a<<8|b;
	}


	static unsigned short get(unsigned short *p) {
		return (((*p)<<8)&0xFF00)|((*p)>>8);
	}

	static short get(short *p) {
		return (((*p)<<8)&0xFF00)|((*p)>>8);
	}

	static unsigned int get(unsigned int *p) {
		return ((*p)<<24)|(((*p)<<8)&0xFF0000)|(((*p)>>8)&0xFF00)|((*p)>>24);
	}
	
	Buffer *read(NSString *file,unsigned long index) {
		
		
		//printf("!\n");
		
		Buffer *buffer = new Buffer[1]{0};
		buffer->length = 0;
		buffer->data = nullptr;
		
		
		if([[file pathExtension] isEqualToString:@"aif"]) {
			NSFileHandle *src = [NSFileHandle fileHandleForReadingAtPath:file];
			if(src) {
				NSData *data = [src readDataToEndOfFile];
				
				//printf("%ld\n",[data length]);
				//printf("(%ld-54=)%ld\n",[data length],[data length]-54);
				
				unsigned char *ptr = (unsigned char *)[data bytes];
				
				unsigned long channels = 0;
				
				for(int k=0; k<[data length]-3; k++) {
					
					if(ptr[k]==0x43&&ptr[k+1]==0x4F&&ptr[k+2]==0x4D&&ptr[k+3]==0x4D) {
						channels = get((unsigned short *)(ptr+k+8));
						break;
					}
				}
				
				if(index>=channels) return buffer;

				/*
				dump(ptr);
				
				printf("%u\n",get((unsigned int *)(ptr+4)));
				
				dump(ptr+8);
				dump(ptr+12);
				
				printf("%u\n",get((unsigned int *)(ptr+16)));
				printf("%u\n",get((unsigned short *)(ptr+20)));
				printf("%u\n",get((unsigned int *)(ptr+22))); // 2830080/(3*2)
				printf("%u\n",get((unsigned short *)(ptr+26)));
				
				// http://neko819.blog.fc2.com/blog-date-201401.html
				printf("%u\n",get((unsigned short *)(ptr+28))); // 16398
				printf("%u\n",get((unsigned short *)(ptr+30))); // 44100 
				printf("%u\n",get((unsigned short *)(ptr+32))); // 0
				printf("%u\n",get((unsigned short *)(ptr+34))); // 0
				printf("%u\n",get((unsigned short *)(ptr+36))); // 0
				
				dump(ptr+38);
				printf("%u\n",get((unsigned int *)(ptr+42)));
				printf("%u\n",get((unsigned int *)(ptr+46)));
				printf("%u\n",get((unsigned int *)(ptr+50)));
				
				*/
				
				int offset = -1;
				int length = 0;
				
				for(int k=0; k<[data length]-3; k++) {
					
					if(ptr[k]==0x53&&ptr[k+1]==0x53&&ptr[k+2]==0x4E&&ptr[k+3]==0x44) {
						
						//printf("%d\n",k);
						length = get((unsigned int *)(ptr+k+4))-(4*2);
						offset = k+4*4;
						break;
						
					}
				}
								
				if(offset!=-1&&length!=0) {
					
					buffer->length = length/2/channels;
					buffer->data = new double[buffer->length]{0};

					unsigned char *wav = ptr+offset; 
					for(int k=0; k<buffer->length; k++) {
				
						buffer->data[k] = from(wav+k*2*channels+index*2);
					}
				}
				
			}
		}
		
		return buffer;
	}	
	
	void write(NSString *path,unsigned short *ptr,long size,long channels) {
		
		size<<=1; // short
		
		NSMutableData *aif = [[NSMutableData alloc] init];
		NSData *buffer = [[NSData alloc] initWithBytes:ptr length:size];
		
		[aif appendBytes:new unsigned char[4]{'F','O','R','M'} length:4];
		[aif appendBytes:new unsigned int[1]{0} length:4];
		[aif appendBytes:new unsigned char[4]{'A','I','F','F'} length:4];

		// Common Chunk
		[aif appendBytes:new unsigned char[4]{'C','O','M','M'} length:4];
		[aif appendBytes:swap(new unsigned int[1]{18}) length:4];
		[aif appendBytes:swap(new unsigned short[1]{0}) length:2];  
		
		[aif appendBytes:new unsigned int[1]{0} length:4]; 
		[aif appendBytes:swap(new unsigned short[1]{16}) length:2];  
		[aif appendBytes:swap(new unsigned short[1]{16398}) length:2];
		[aif appendBytes:swap(new unsigned short[1]{44100}) length:2];
		[aif appendBytes:new unsigned short[3]{0} length:(3*2)];

		// SoundData Chunk
		[aif appendBytes:new char[4]{'S','S','N','D'} length:4];
		
		long length = [buffer length];
		unsigned int num = length+8;
		[aif appendBytes:swap(&num) length:4];
		[aif appendBytes:new int[1]{0} length:4]; // offset
		[aif appendBytes:new int[1]{0} length:4]; // block size
		[aif appendBytes:buffer.bytes length:length];
		
		*((unsigned int *)(((unsigned char *)aif.bytes)+4)) = swap((unsigned int)([aif length])-8);	
		*((unsigned short *)(((unsigned char *)aif.bytes)+20)) = swap((unsigned short)(channels));
		*((unsigned short *)(((unsigned char *)aif.bytes)+22)) = swap((unsigned short)(length/channels));
		
		[aif writeToFile:path options:NSDataWritingAtomic error:nil];

	}
}

int main(int argc, char *argv[]) {
	
	@autoreleasepool {
		
		AIFF::Buffer *buffer = AIFF::read(DESKTOP_PATH(@"src.aif"),2);
		if(buffer->length<=0) return 0;
		
		long channels = 1;
		long index = 1;
		long length = buffer->length*channels;
		unsigned short *data = new unsigned short[length]{0};
		
		for(int k=0; k<buffer->length; k++) {
			data[k*channels+index] = AIFF::to(buffer->data[k]);
		}

		AIFF::write(DESKTOP_PATH(@"dst.aif"),buffer->data,length,channels);
		
	}
}